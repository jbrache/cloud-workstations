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
# Workstation Outputs
# -------------------------------------------------------------------

output "workstation_cluster_id" {
  description = "The ID of the workstation cluster"
  value       = google_workstations_workstation_cluster.default.id
}

output "workstation_cluster_name" {
  description = "The name of the workstation cluster"
  value       = google_workstations_workstation_cluster.default.workstation_cluster_id
}

output "workstation_config_id" {
  description = "The ID of the workstation configuration"
  value       = google_workstations_workstation_config.default.id
}

output "workstation_config_name" {
  description = "The name of the workstation configuration"
  value       = google_workstations_workstation_config.default.workstation_config_id
}

output "workstation_ids" {
  description = "List of workstation IDs created"
  value       = [for ws in google_workstations_workstation.user : ws.id]
}

output "workstation_names" {
  description = "Map of developer names to their workstation names"
  value = {
    for idx, name in var.developers_name :
    name => google_workstations_workstation.user[idx].workstation_id
  }
}

# -------------------------------------------------------------------
# Network Outputs
# -------------------------------------------------------------------

output "vpc_network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_id" {
  description = "The ID of the workstations subnet"
  value       = google_compute_subnetwork.workstations_subnet.id
}

output "subnet_name" {
  description = "The name of the workstations subnet"
  value       = google_compute_subnetwork.workstations_subnet.name
}

# -------------------------------------------------------------------
# Container Outputs
# -------------------------------------------------------------------

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.workstations_repo.repository_id}"
}

output "container_image" {
  description = "Full path to the container image"
  value       = "${local.container_image}:latest"
}

# -------------------------------------------------------------------
# Service Account Outputs
# -------------------------------------------------------------------

output "service_account_email" {
  description = "Email of the workstation service account"
  value       = google_service_account.workstation_sa.email
}

output "service_account_id" {
  description = "ID of the workstation service account"
  value       = google_service_account.workstation_sa.id
}

# -------------------------------------------------------------------
# Access Outputs
# -------------------------------------------------------------------

output "workstations_console_url" {
  description = "URL to the Cloud Workstations console"
  value       = "https://console.cloud.google.com/workstations/list?project=${var.project_id}"
}

output "gcloud_start_command" {
  description = "gcloud command to start a workstation"
  value       = "gcloud workstations start <workstation-name> --cluster=${google_workstations_workstation_cluster.default.workstation_cluster_id} --config=${google_workstations_workstation_config.default.workstation_config_id} --region=${var.region}"
}

output "gcloud_ssh_command" {
  description = "gcloud command to SSH into a workstation"
  value       = "gcloud workstations ssh <workstation-name> --cluster=${google_workstations_workstation_cluster.default.workstation_cluster_id} --config=${google_workstations_workstation_config.default.workstation_config_id} --region=${var.region}"
}
