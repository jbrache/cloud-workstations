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

# ===================================================================
# ANTIGRAVITY WORKSTATION CONFIGURATION (OPTIONAL)
# ===================================================================
# Set enable_antigravity_workstation = true in terraform.tfvars to deploy
# Antigravity IDE workstations alongside VS Code workstations.
# All resources in this file are conditional on that variable.
# ===================================================================

# -------------------------------------------------------------------
# Container Build - Antigravity
# -------------------------------------------------------------------
resource "null_resource" "build_antigravity_container_image" {
  count = var.enable_antigravity_workstation ? 1 : 0

  provisioner "local-exec" {
    command     = "gcloud builds submit ${local.antigravity_folder_selection} --tag='${local.antigravity_container_image}:${local.container_image_tag}' --project ${var.project_id}"
    working_dir = path.module
  }

  triggers = {
    container_folder_hash = local.antigravity_container_folder_fingerprint
    # Uncomment to force rebuild on every apply:
    # timestamp = timestamp()
  }

  depends_on = [
    google_artifact_registry_repository.workstations_repo,
  ]
}

# -------------------------------------------------------------------
# Workstation Config - Antigravity
# -------------------------------------------------------------------
resource "google_workstations_workstation_config" "antigravity" {
  count                  = var.enable_antigravity_workstation ? 1 : 0
  provider               = google-beta
  project                = var.project_id
  workstation_config_id  = "${var.workstation_config_name}-antigravity"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location               = var.region

  labels = merge(local.common_labels, {
    "cloud-workstations-ide" = "antigravity"
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
    image       = "${local.antigravity_container_image}:${local.container_image_tag}"
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

  depends_on = [null_resource.build_antigravity_container_image]
}

# -------------------------------------------------------------------
# Workstations - Antigravity
# -------------------------------------------------------------------
resource "google_workstations_workstation" "antigravity_user" {
  count                  = var.enable_antigravity_workstation ? length(var.developers_email) : 0
  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_id         = "antigravity-ws-${var.developers_name[count.index]}"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.antigravity[0].workstation_config_id

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

resource "google_workstations_workstation_iam_member" "antigravity_user" {
  count                  = var.enable_antigravity_workstation ? length(var.developers_email) : 0
  provider               = google-beta
  project                = var.project_id
  location               = var.region
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.antigravity[0].workstation_config_id
  workstation_id         = google_workstations_workstation.antigravity_user[count.index].workstation_id
  role                   = "roles/workstations.user"
  member                 = "user:${var.developers_email[count.index]}"
}

# -------------------------------------------------------------------
# Cloud Build Trigger - Antigravity
# -------------------------------------------------------------------
resource "google_cloudbuild_trigger" "antigravity_container_image" {
  count       = var.enable_antigravity_workstation && var.schedule_container_rebuilds ? 1 : 0
  project     = var.project_id
  name        = "workstations-antigravity-image-trigger"
  description = "Trigger to build Cloud Workstations Antigravity container image"
  location    = "global"

  source_to_build {
    uri       = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}"
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }

  git_file_source {
    path      = "vscode-image-ds/${local.antigravity_folder_selection}/cloudbuild.yaml"
    uri       = "https://github.com/${var.github_repo_owner}/${var.github_repo_name}"
    revision  = "refs/heads/main"
    repo_type = "GITHUB"
  }

  substitutions = {
    _REGION        = var.region
    _AR_REPO_NAME  = var.artifact_repo_name
    _AR_IMAGE_NAME = var.antigravity_artifact_image_name
    _TAG           = local.container_image_tag
    _IMAGE_DIR     = "vscode-image-ds/${local.antigravity_folder_selection}"
  }

  depends_on = [
    google_artifact_registry_repository.workstations_repo,
  ]
}

# -------------------------------------------------------------------
# Cloud Scheduler Job - Antigravity
# -------------------------------------------------------------------
# Scheduled job to trigger antigravity container image rebuild every Sunday at 12am UTC
resource "google_cloud_scheduler_job" "antigravity_trigger_build" {
  count       = var.enable_antigravity_workstation && var.schedule_container_rebuilds ? 1 : 0
  project     = var.project_id
  name        = "workstations-antigravity-image-rebuild"
  description = "Scheduled trigger to rebuild Cloud Workstations Antigravity container image"
  region      = var.region
  schedule    = var.container_rebuild_schedule
  time_zone   = "UTC"

  http_target {
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/locations/global/triggers/${google_cloudbuild_trigger.antigravity_container_image[0].trigger_id}:run"
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.cloudbuild_sa[0].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_cloudbuild_trigger.antigravity_container_image,
    time_sleep.wait_for_sa_roles,
  ]
}
