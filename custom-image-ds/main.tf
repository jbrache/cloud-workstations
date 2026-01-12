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

# -------------------------------------------------------------------
# ---------- Use Existing Project ----------
# Enable required APIs on the existing project
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "workstations.googleapis.com"
  ])

  project = var.project_id
  service = each.key

  disable_on_destroy = false
}

# Wait after enabling APIs
resource "time_sleep" "wait_for_project_apis" {
  depends_on = [
    google_project_service.required_apis,
  ]
  create_duration = "5s"
}


resource "google_project_organization_policy" "require_shielded_vm" {
  project    = var.project_id
  constraint = "compute.requireShieldedVm"

  boolean_policy {
    enforced = false
  }
}

resource "time_sleep" "wait_for_org_policy" {
  depends_on      = [google_project_organization_policy.require_shielded_vm]
  create_duration = "90s"
}

# -------------------------------------------------------------------
# ---------- Service Account and IAM ----------
resource "google_service_account" "workstation_sa" {
  project      = var.project_id
  account_id   = "cloud-workstations-sa"
  display_name = "Cloud Workstations Service Account"
}

resource "google_project_iam_member" "workstations_iam_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${google_service_account.workstation_sa.email}"
}

resource "google_project_iam_member" "workstations_iam_source_repo" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.workstation_sa.email}"
}

resource "google_project_iam_member" "workstations_iam_logwriter" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workstation_sa.email}"
}

# -------------------------------------------------------------------
# ---------- VPC Network and Firewalls ----------
resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "workstations-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "workstations_subnet" {
  project                  = var.project_id
  name                     = "${var.region}-workstations"
  ip_cidr_range            = var.subnetwork_range
  region                   = var.region
  private_ip_google_access = true
  network                  = google_compute_network.vpc_network.name

}

resource "google_compute_firewall" "workstation-egress" {
  name    = "workstation-internal-egress"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["980", "443"]
  }

  priority    = "10"
  direction   = "EGRESS"
  target_tags = ["cloud-workstations-instance"]
}

#workstation internal ingress
resource "google_compute_firewall" "workstation-ingress" {
  name    = "workstation-internal-ingress"
  network = google_compute_network.vpc_network.name
  project = var.project_id

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

resource "google_artifact_registry_repository" "workstations-repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "workstations-vscode"
  description   = "Docker repository for Cloud Worstations"
  format        = "DOCKER"

  docker_config {
# Set to false to allow tag overwrites
    immutable_tags = false
  }
}

# Cloud Router for NAT
resource "google_compute_router" "workstations_router" {
  project = var.project_id
  name    = "workstations-router-${var.region}"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

# Cloud NAT for private workstations
resource "google_compute_router_nat" "workstations_nat" {
  project                            = var.project_id
  name                               = "workstations-nat-${var.region}"
  router                             = google_compute_router.workstations_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

locals {
  network_id                    = google_compute_network.vpc_network.id
  subnet_id                     = google_compute_subnetwork.workstations_subnet.id
  workstations_container_image  = "${var.region}-docker.pkg.dev/${var.project_id}/workstations-vscode/workstations-vscode"
  container_folder_path = "${path.module}/workstation-container"
  # 1. 'fileset' finds all files matching the pattern
  # 2. The loop runs 'filemd5' on every file found
  # 3. 'join' merges all individual hashes into one long string
  # 4. The outer 'md5' hashes that string into a single unique fingerprint
  container_folder_fingerprint = md5(join("", [
    for f in fileset(local.container_folder_path, "**") : filemd5("${local.container_folder_path}/${f}")
  ]))
}

resource "null_resource" "build_container_image" {
  provisioner "local-exec" {
    command     = <<EOF
gcloud config set project ${var.project_id}
gcloud builds submit workstation-container --tag="${var.region}-docker.pkg.dev/${var.project_id}/workstations-vscode/workstations-vscode:latest" --project ${var.project_id}
EOF
    working_dir = path.module
  }
  
  depends_on = [
    google_artifact_registry_repository.workstations-repo,
    google_project_service.required_apis
  ]
  
  triggers = {
    container_folder_hash = local.container_folder_fingerprint
    # Uncomment to force rebuild on every apply:
    # timestamp = timestamp()
  }
}

# Creating  workstation cluster 
resource "google_workstations_workstation_cluster" "default_config" {
  provider               = google-beta
  project                = var.project_id
  workstation_cluster_id = "tf-ws-cluster"
  network                = local.network_id
  subnetwork             = local.subnet_id
  location               = var.region

  labels = {
    "cloud-workstations-instance" = "vscode"
  }
}

resource "google_compute_project_metadata" "default" {
  metadata = {
    enable-guest-attributes    = "TRUE"
    enable-osconfig            = "TRUE"
    enable-oslogin             = "TRUE"
    google-monitoring-enabled  = "TRUE"
  }
}

# Creating workstation config 
resource "google_workstations_workstation_config" "default_config" {
  provider               = google-beta
  workstation_config_id  = "tf-ws-config"
  workstation_cluster_id = google_workstations_workstation_cluster.default_config.workstation_cluster_id
  location               = var.region
  project                = var.project_id

  host {
    gce_instance {
      machine_type                = "e2-standard-4"
      boot_disk_size_gb           = 50
      disable_public_ip_addresses = true
      service_account             = google_service_account.workstation_sa.email
      tags = ["workstation"]
    }
  }

  container {
    image       = "${local.workstations_container_image}:latest"
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

  depends_on = [google_workstations_workstation_cluster.default_config]
}

# Workstation creation
resource "google_workstations_workstation" "workstation_user" {
  count                  = length(var.developers_email)
  provider               = google-beta
  workstation_id         = "workstation-${var.developers_name[count.index]}"
  workstation_config_id  = google_workstations_workstation_config.default_config.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.default_config.workstation_cluster_id
  location               = var.region
  project                = var.project_id
  env = {
    OSLOGIN_USER = "${var.developers_email[count.index]}"
    CLAUDE_CODE_USE_VERTEX = 1
    CLOUD_ML_REGION = "us-east5"
    ANTHROPIC_VERTEX_PROJECT_ID = "${var.project_id}"
    GOOGLE_GENAI_USE_VERTEXAI = true
    GOOGLE_CLOUD_LOCATION = "${var.region}"
    GOOGLE_CLOUD_PROJECT = "${var.project_id}"
  }

  depends_on = [google_workstations_workstation_cluster.default_config]
}

# iam permissions to access workstation i.e workstations.user
resource "google_workstations_workstation_iam_member" "member" {
  count                  = length(var.developers_email)
  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.default_config.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.default_config.workstation_config_id
  workstation_id         = "workstation-${var.developers_name[count.index]}"
  role                   = "roles/workstations.user"
  member                 = "user:${var.developers_email[count.index]}"

  depends_on = [google_workstations_workstation.workstation_user]
}

