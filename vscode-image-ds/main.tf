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
# Local Variables
# -------------------------------------------------------------------
locals {
  # Network references
  network_id = google_compute_network.vpc_network.id
  subnet_id  = google_compute_subnetwork.workstations_subnet.id

  # Container image path - VS Code
  vscode_container_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/${var.artifact_image_name}"
  container_image_tag    = "latest"

  # Container build fingerprint for change detection - VS Code
  vscode_container_folder_path = "${path.module}/workstation-container-vscode"
  vscode_container_folder_fingerprint = md5(join("", [
    for f in fileset(local.vscode_container_folder_path, "**") : filemd5("${local.vscode_container_folder_path}/${f}")
  ]))

  # Container image path - Antigravity
  antigravity_container_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/${var.antigravity_artifact_image_name}"

  # Container build fingerprint for change detection - Antigravity
  antigravity_container_folder_path = "${path.module}/workstation-container-antigravity"
  antigravity_container_folder_fingerprint = md5(join("", [
    for f in fileset(local.antigravity_container_folder_path, "**") : filemd5("${local.antigravity_container_folder_path}/${f}")
  ]))

  # Common labels for all resources
  common_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
  })

  # Network tag for firewall rules
  workstation_tag = "cloud-workstations"
}

# -------------------------------------------------------------------
# Project Configuration
# -------------------------------------------------------------------
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "workstations.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "time_sleep" "wait_for_apis" {
  depends_on      = [google_project_service.required_apis]
  create_duration = var.api_activation_wait
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
  create_duration = var.org_policy_wait
}

resource "google_compute_project_metadata" "default" {
  project = var.project_id
  metadata = {
    enable-guest-attributes   = "TRUE"
    enable-osconfig           = "TRUE"
    enable-oslogin            = "TRUE"
    google-monitoring-enabled = "TRUE"
  }
}

# -------------------------------------------------------------------
# Service Account and IAM
# -------------------------------------------------------------------
resource "google_service_account" "workstation_sa" {
  project      = var.project_id
  account_id   = var.cloudworkstations_service_account_id
  display_name = "Cloud Workstations Service Account"
}

resource "google_project_iam_member" "workstation_sa_roles" {
  for_each = toset([
    "roles/compute.networkUser",
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workstation_sa.email}"
}

# Cloud Build service account for triggering builds via Cloud Scheduler
resource "google_service_account" "cloudbuild_sa" {
  count        = var.schedule_container_rebuilds ? 1 : 0
  project      = var.project_id
  account_id   = var.cloudbuild_service_account_id
  display_name = "Cloud Build Trigger Service Account"
}

# Grant Cloud Build Service Account role to the Cloud Build service account for trigger invocation
# Grant Artifact Registry Repository Administrator role to default Cloud Build service account for image uploads
resource "google_project_iam_member" "cloudbuild_sa_roles" {
  for_each = var.schedule_container_rebuilds ? toset([
    "roles/cloudbuild.builds.builder",
    "roles/artifactregistry.repoAdmin"
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloudbuild_sa[0].email}"
}

# Data source to get project number for default Cloud Build SA
data "google_project" "main" {
  project_id = var.project_id
}

resource "time_sleep" "wait_for_sa_roles" {
  depends_on      = [google_project_iam_member.workstation_sa_roles, google_project_iam_member.cloudbuild_sa_roles]
  create_duration = "10s"
}

# -------------------------------------------------------------------
# VPC Network
# -------------------------------------------------------------------
resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "workstations_subnet" {
  project                  = var.project_id
  name                     = "${var.region}-workstations"
  ip_cidr_range            = var.subnetwork_range
  region                   = var.region
  network                  = google_compute_network.vpc_network.name
  private_ip_google_access = true
}

# -------------------------------------------------------------------
# Firewall Rules
# -------------------------------------------------------------------
resource "google_compute_firewall" "workstation_egress" {
  project     = var.project_id
  name        = "cloud-workstations-egress"
  network     = google_compute_network.vpc_network.name
  direction   = "EGRESS"
  priority    = 10
  target_tags = [local.workstation_tag]

  allow {
    protocol = "tcp"
    ports    = ["443", "980"]
  }
}

resource "google_compute_firewall" "workstation_ingress" {
  project       = var.project_id
  name          = "cloud-workstations-ingress"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = 20
  target_tags   = [local.workstation_tag]
  source_ranges = [var.subnetwork_range]

  allow { protocol = "icmp" }
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
}

# -------------------------------------------------------------------
# Cloud NAT
# -------------------------------------------------------------------
resource "google_compute_router" "workstations_router" {
  project = var.project_id
  name    = "workstations-router-${var.region}"
  region  = var.region
  network = local.network_id
}

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

# -------------------------------------------------------------------
# Artifact Registry
# -------------------------------------------------------------------
resource "google_artifact_registry_repository" "workstations_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repo_name
  description   = "Docker repository for Cloud Workstations"
  format        = "DOCKER"

  # docker_config {
  #   immutable_tags = false
  # }
  depends_on = [time_sleep.wait_for_apis]
}

# -------------------------------------------------------------------
# Container Build - VS Code
# -------------------------------------------------------------------
resource "null_resource" "build_vscode_container_image" {
  provisioner "local-exec" {
    command     = "gcloud builds submit workstation-container-vscode --tag='${local.vscode_container_image}:${local.container_image_tag}' --project ${var.project_id}"
    working_dir = path.module
  }

  triggers = {
    container_folder_hash = local.vscode_container_folder_fingerprint
    # Uncomment to force rebuild on every apply:
    # timestamp = timestamp()
  }

  depends_on = [
    google_artifact_registry_repository.workstations_repo,
  ]
}


# -------------------------------------------------------------------
# Workstation Cluster
# -------------------------------------------------------------------
resource "google_workstations_workstation_cluster" "default" {
  provider               = google-beta
  project                = var.project_id
  workstation_cluster_id = var.workstation_cluster_name
  location               = var.region
  network                = local.network_id
  subnetwork             = local.subnet_id
  labels                 = local.common_labels
}

# -------------------------------------------------------------------
# Workstation Config - VS Code
# -------------------------------------------------------------------
resource "google_workstations_workstation_config" "default" {
  provider               = google-beta
  project                = var.project_id
  workstation_config_id  = "${var.workstation_config_name}-vscode"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location               = var.region

  labels = merge(local.common_labels, {
    "cloud-workstations-ide" = "vscode"
  })

  idle_timeout    = var.idle_timeout
  running_timeout = var.running_timeout

  host {
    gce_instance {
      machine_type                = var.machine_type
      boot_disk_size_gb           = 50
      disable_public_ip_addresses = true
      service_account             = google_service_account.workstation_sa.email
      tags                        = [local.workstation_tag]
    }
  }

  container {
    image       = "${local.vscode_container_image}:${local.container_image_tag}"
    working_dir = "/home"
    env = {
      CLOUD_WORKSTATIONS_CONFIG_DISABLE_SUDO = false
    }
  }

  persistent_directories {
    mount_path = "/home"
    gce_pd {
      size_gb        = var.persistent_disk_size_gb
      disk_type      = var.persistent_disk_type
      reclaim_policy = var.persistent_disk_reclaim_policy
    }
  }

  depends_on = [null_resource.build_vscode_container_image]
}


# -------------------------------------------------------------------
# Workstations - VS Code
# -------------------------------------------------------------------
resource "google_workstations_workstation" "user" {
  count                  = length(var.developers_email)
  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_id         = "vscode-ws-${var.developers_name[count.index]}"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.default.workstation_config_id

  env = {
    OSLOGIN_USER = var.developers_email[count.index]
    # Claude
    CLAUDE_CODE_USE_VERTEX      = 1
    CLOUD_ML_REGION             = "us-east5"
    ANTHROPIC_VERTEX_PROJECT_ID = var.project_id
    # ADK
    GOOGLE_GENAI_USE_VERTEXAI = true
    GOOGLE_CLOUD_LOCATION     = var.region
    GOOGLE_CLOUD_PROJECT      = var.project_id
    # Goose
    GCP_PROJECT_ID = var.project_id
    GCP_LOCATION   = var.region
  }
}

resource "google_workstations_workstation_iam_member" "user" {
  count                  = length(var.developers_email)
  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.default.workstation_config_id
  workstation_id         = google_workstations_workstation.user[count.index].workstation_id
  role                   = "roles/workstations.user"
  member                 = "user:${var.developers_email[count.index]}"
}


# -------------------------------------------------------------------
# Cloud Build Trigger - VS Code
# -------------------------------------------------------------------
# https://docs.cloud.google.com/workstations/docs/tutorial-automate-container-image-rebuild
resource "google_cloudbuild_trigger" "container_image" {
  count       = var.schedule_container_rebuilds ? 1 : 0
  project     = var.project_id
  name        = "workstations-vscode-image-trigger"
  description = "Trigger to build Cloud Workstations VS Code container image"
  location    = "global"

  source_to_build {
    uri       = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}"
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }

  git_file_source {
    path      = "vscode-image-ds/workstation-container-vscode/cloudbuild.yaml"
    uri       = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}"
    revision  = "refs/heads/main"
    repo_type = "GITHUB"
  }

  substitutions = {
    _REGION        = var.region
    _AR_REPO_NAME  = var.artifact_repo_name
    _AR_IMAGE_NAME = var.artifact_image_name
    _TAG           = local.container_image_tag
    _IMAGE_DIR     = "vscode-image-ds/workstation-container-vscode"
  }

  depends_on = [
    google_artifact_registry_repository.workstations_repo,
  ]
}

# -------------------------------------------------------------------
# Cloud Scheduler Job - VS Code
# -------------------------------------------------------------------
# Scheduled job to trigger container image rebuild every Sunday at 12am UTC
resource "google_cloud_scheduler_job" "trigger_build" {
  count       = var.schedule_container_rebuilds ? 1 : 0
  project     = var.project_id
  name        = "workstations-vscode-image-rebuild"
  description = "Scheduled trigger to rebuild Cloud Workstations VS Code container image"
  region      = var.region
  schedule    = var.container_rebuild_schedule
  time_zone   = "UTC"

  http_target {
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/locations/global/triggers/${google_cloudbuild_trigger.container_image[0].trigger_id}:run"
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.cloudbuild_sa[0].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_cloudbuild_trigger.container_image,
    time_sleep.wait_for_sa_roles,
  ]
}
