/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# ----------------------------------------
# Create Project
# ----------------------------------------
module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.5"

  name              = "${var.project_name}-${var.environment}-${random_id.random_suffix.hex}"
  random_project_id = "false"
  org_id            = var.org_id
  folder_id         = var.folder_id
  billing_account   = var.billing_account

  activate_apis = [
    "iam.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "networkservices.googleapis.com",
    "certificatemanager.googleapis.com",
    "storage.googleapis.com",
    "workstations.googleapis.com"
  ]
}

module "org-policy-requireShieldedVm" {
  source      = "terraform-google-modules/org-policy/google"
  policy_for  = "project"
  project_id  = module.project.project_id
  constraint  = "compute.requireShieldedVm"
  policy_type = "boolean"
  enforce     = false
}

resource "time_sleep" "wait_for_org_policy" {
  depends_on      = [module.org-policy-requireShieldedVm]
  create_duration = "90s"
}

resource "random_id" "random_suffix" {
  byte_length = 4
}

# ----------------------------------------
# Service Account and IAM
# ----------------------------------------
resource "google_service_account" "main" {
  project      = module.project.project_id
  account_id   = "${var.environment}-${random_id.random_suffix.hex}"
  display_name = "${var.environment}${random_id.random_suffix.hex}"
}

resource "google_project_iam_member" "workstations_iam_network_user" {
  project = module.project.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "workstations_iam_source_repo" {
  project = module.project.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_project_iam_member" "workstations_iam_logwriter" {
  project = module.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.main.email}"
}

# ----------------------------------------
# VPC Network and Firewalls
# ----------------------------------------
resource "google_compute_network" "vpc_network" {
  project                 = module.project.project_id
  name                    = "${var.environment}-${random_id.random_suffix.hex}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "workstations_subnet" {
  project                  = module.project.project_id
  name                     = "${var.environment}-${random_id.random_suffix.hex}"
  ip_cidr_range            = var.subnetwork_range
  region                   = var.region
  private_ip_google_access = true
  network                  = google_compute_network.vpc_network.name
}

resource "google_compute_router" "router" {
  project                  = module.project.project_id
  name                     = "workstations-router"
  region                   = google_compute_subnetwork.workstations_subnet.region
  network                  = google_compute_network.vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  project                            = module.project.project_id
  name                               = "workstations-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "workstation-egress" {
  name    = "workstation-internal-egress"
  network = google_compute_network.vpc_network.name
  project = module.project.project_id

  allow {
    protocol = "tcp"
    ports    = ["980", "443"]
  }

  priority    = "10"
  direction   = "EGRESS"
  target_tags = ["cloud-workstations-instance"]
}

# ----------------------------------------
# Workstation Internal Ingress
# ----------------------------------------
resource "google_compute_firewall" "workstation-ingress" {
  name    = "workstation-internal-ingress"
  network = google_compute_network.vpc_network.name
  project = module.project.project_id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  target_tags   = []
  source_ranges = [var.subnetwork_range] 
  direction     = "INGRESS"
  priority      = "20"
}

locals {
  network_id                    = google_compute_network.vpc_network.id
  subnet_id                     = google_compute_subnetwork.workstations_subnet.id
  workstations_container_image  = var.workstations_container_image
}

# ----------------------------------------
# Create Workstation Cluster
# ----------------------------------------
resource "google_workstations_workstation_cluster" "cluster" {
  provider               = google-beta
  project                = module.project.project_id
  workstation_cluster_id = "workstation-terraform"
  network                = local.network_id
  subnetwork             = local.subnet_id
  location               = var.region

  labels = {
    "cloud-workstations-instance" = "code-oss"
  }
}

# ----------------------------------------
# Create Workstation Config 
# ----------------------------------------
resource "google_workstations_workstation_config" "config" {
  provider               = google-beta
  workstation_config_id  = "workstation-config-terraform"
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  location               = var.region
  project                = module.project.project_id

  host {
    gce_instance {
      machine_type                = "e2-standard-4"
      boot_disk_size_gb           = 50
      disable_public_ip_addresses = true # Use true if you don't want public ip, you need to use nat in this case
      service_account             = google_service_account.main.email
      tags = ["workstation"]
    }
  }

  container {
    image       = "${local.workstations_container_image}"
    working_dir = "/home"
    env = {
      CLOUD_WORKSTATIONS_CONFIG_DISABLE_SUDO = false
    }
  }

  persistent_directories {
    mount_path = "/home" 
    gce_pd {
      size_gb        = 200
      disk_type      = "pd-ssd"
      reclaim_policy = "DELETE" # delete the disk after the workstation is deleted.
    }
  }

  depends_on = [google_workstations_workstation_cluster.cluster]
}

# ----------------------------------------
# Workstation Creation
# ----------------------------------------
resource "google_workstations_workstation" "workstation" {
  count                  = length(var.developers_email)
  provider               = google-beta
  workstation_id         = "workstation-${var.developers_name[count.index]}"
  workstation_config_id  = google_workstations_workstation_config.config.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  location               = var.region
  project                = module.project.project_id

  depends_on = [google_workstations_workstation_config.config]
}

# ----------------------------------------
# IAM permissions to access workstation i.e workstations.user
# ----------------------------------------
resource "google_workstations_workstation_iam_member" "member" {
  count                  = length(var.developers_email)
  provider               = google-beta
  project                = module.project.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.cluster.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.config.workstation_config_id
  workstation_id         = "workstation-${var.developers_name[count.index]}"
  role                   = "roles/workstations.user"
  member                 = "user:${var.developers_email[count.index]}"

  depends_on = [google_workstations_workstation.workstation]
}
