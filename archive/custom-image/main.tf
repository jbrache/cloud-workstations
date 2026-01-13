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
# ---------- Create Project ----------
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
    # "notebooks.googleapis.com",
    # "containerregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    # "aiplatform.googleapis.com",
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

# -------------------------------------------------------------------
# ---------- Service Account and IAM ----------
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

# resource "google_project_iam_member" "notebook_iam_compute" {
#   project = module.project.project_id
#   role    = "roles/compute.admin"
#   member  = "serviceAccount:${google_service_account.main.email}"
# }

# resource "google_project_iam_member" "source_repo" {
#   project = module.project.project_id
#   role    = "roles/source.reader"
#   member  = "serviceAccount:${google_service_account.main.email}"
# }

# resource "google_project_iam_member" "notebook_iam_serviceaccount" {
#   project = module.project.project_id
#   role    = "roles/iam.serviceAccountUser"
#   member  = "serviceAccount:${google_service_account.main.email}"
# }

# -------------------------------------------------------------------
# ---------- VPC Network and Firewalls ----------
resource "google_compute_network" "vpc_network" {
  project                 = module.project.project_id
  name                    = "${var.environment}-${random_id.random_suffix.hex}"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "workstations_subnet" {
  project                  = module.project.project_id
  name                     = "${var.environment}-${random_id.random_suffix.hex}-workstations"
  ip_cidr_range            = var.subnetwork_range
  region                   = var.region
  private_ip_google_access = true
  network                  = google_compute_network.vpc_network.name

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

#workstation internal ingress
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

resource "google_artifact_registry_repository" "workstations-repo" {
  project       = module.project.project_id
  location      = var.region
  repository_id = "workstations-vscode"
  description   = "Docker repository for Cloud Worstations"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }
}

# resource "google_cloudbuild_trigger" "build-trigger" {
#   name = "my-trigger"
#   location = "global"

#   trigger_template {
#     branch_name = "main"
#     repo_name   = "my-repo"
#   }

#   build {
#     step {
#       name = "gcr.io/cloud-builders/gsutil"
#       args = ["cp", "gs://mybucket/remotefile.zip", "localfile.zip"]
#       timeout = "120s"
#       secret_env = ["MY_SECRET"]
#     }
#   }
# }

# locals {
#     yaml_file = templatefile("cloudbuild.yaml",
#       {
#         yaml_code = indent(2, yamlencode(["this is a line", "this is 2nd line"]))
#       }
#     )
# }
locals {
  network_id                    = google_compute_network.vpc_network.id
  subnet_id                     = google_compute_subnetwork.workstations_subnet.id
  workstations_container_image  = "${var.region}-docker.pkg.dev/${module.project.project_id}/workstations-vscode/workstations-vscode"
}

# resource "null_resource" "build_container_image" {
#   provisioner "local-exec" {
#     command = <<EOF
#     gcloud config set project ${module.project.project_id}
#     gcloud builds submit . --tag="${var.region}-docker.pkg.dev/${module.project.project_id}/workstations-vscode/workstations-vscode" --project ${module.project.project_id}
#     EOF
#   }
#   depends_on = [google_artifact_registry_repository.workstations-repo]
# }

# Creating  workstation cluster 
resource "google_workstations_workstation_cluster" "cluster_public" {
  provider               = google-beta
  project                = module.project.project_id
  workstation_cluster_id = "workstation-terraform-public"
  network                = local.network_id
  subnetwork             = local.subnet_id
  location               = var.region

  labels = {
    "cloud-workstations-instance" = "vscode"
  }
}

# Creating workstation config 
resource "google_workstations_workstation_config" "config_public" {
  provider               = google-beta
  workstation_config_id  = "workstation-config-terraform-public"
  workstation_cluster_id = google_workstations_workstation_cluster.cluster_public.workstation_cluster_id
  location               = var.region
  project                = module.project.project_id

  host {
    gce_instance {
      machine_type                = "e2-standard-4"
      boot_disk_size_gb           = 50
      disable_public_ip_addresses = false #Use true if you don't want public ip, you need to use nat in this case
      # service_account             = google_service_account.workstation-svc.email
      service_account             = google_service_account.main.email
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

  depends_on = [google_workstations_workstation_cluster.cluster_public]
}

# Workstation creation
resource "google_workstations_workstation" "workstation_public" {
  count                  = length(var.developers_email)
  provider               = google-beta
  # workstation_id         = "workstation-terraform-public"
  workstation_id         = "workstation-public-${var.developers_name[count.index]}"
  workstation_config_id  = google_workstations_workstation_config.config_public.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.cluster_public.workstation_cluster_id
  location               = var.region
  project                = module.project.project_id

  depends_on = [google_workstations_workstation_cluster.cluster_public]
}

# iam permissions to access workstation i.e workstations.user
resource "google_workstations_workstation_iam_member" "member" {
  count                  = length(var.developers_email)
  provider               = google-beta
  project                = module.project.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.cluster_public.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.config_public.workstation_config_id
  # workstation_id         = google_workstations_workstation.workstation_public.workstation_id
  workstation_id         = "workstation-public-${var.developers_name[count.index]}"
  role                   = "roles/workstations.user"
  member                 = "user:${var.developers_email[count.index]}"

  depends_on = [google_workstations_workstation.workstation_public]
}


# resource "google_cloudbuild_trigger" "filename-trigger" {
#   project       = module.project.project_id
#   location      = var.region

#   trigger_template {
#     tag_name   = "us-central1-docker.pkg.dev/prj-workstations-eaad9418/workstations-vscode"
#   }

#   filename = "cloudbuild.yaml"

#   depends_on = [google_artifact_registry_repository.workstations-repo]
# }

# resource "google_compute_subnetwork" "proxy" {
#   project       = module.project.project_id
#   name          = "${var.environment}-${random_id.random_suffix.hex}-web-proxy"
#   network       = google_compute_network.vpc_network.name
#   region        = var.region
#   ip_cidr_range = "192.168.0.0/23"
#   purpose       = "REGIONAL_MANAGED_PROXY"
#   role          = "ACTIVE"
# }

# resource "google_compute_firewall" "egress" {
#   project            = module.project.project_id
#   name               = "deny-all-egress"
#   description        = "Block all egress ${var.environment}"
#   network            = google_compute_network.vpc_network.name
#   priority           = 1000
#   direction          = "EGRESS"
#   destination_ranges = ["0.0.0.0/0"]
#   deny {
#     protocol = "all"
#   }
# }

# resource "google_compute_firewall" "ingress" {
#   project       = module.project.project_id
#   name          = "deny-all-ingress"
#   description   = "Block all Ingress ${var.environment}"
#   network       = google_compute_network.vpc_network.name
#   priority      = 1000
#   direction     = "INGRESS"
#   source_ranges = ["0.0.0.0/0"]
#   deny {
#     protocol = "all"
#   }
# }

# resource "google_compute_firewall" "googleapi_egress" {
#   project            = module.project.project_id
#   name               = "allow-googleapi-egress"
#   description        = "Allow connectivity to storage ${var.environment}"
#   network            = google_compute_network.vpc_network.name
#   priority           = 999
#   direction          = "EGRESS"
#   destination_ranges = ["199.36.153.8/30"]
#   allow {
#     protocol = "tcp"
#     ports    = ["443", "8080", "80"]
#   }
# }

# resource "google_compute_firewall" "secure_web_proxy_egress" {
#   project            = module.project.project_id
#   name               = "secure-web-proxy"
#   description        = "Allow secure web proxy connectivity ${var.environment}"
#   network            = google_compute_network.vpc_network.name
#   priority           = 998
#   direction          = "EGRESS"
#   destination_ranges = ["10.2.0.0/16"]
#   allow {
#     protocol = "tcp"
#     ports    = ["443"]
#   }
# }



  # depends_on = [google_storage_bucket.bucket, google_storage_bucket_object.post_startup_script, time_sleep.wait_for_org_policy]
