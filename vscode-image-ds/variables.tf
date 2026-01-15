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
# Project Configuration
# -------------------------------------------------------------------

variable "project_id" {
  description = "The existing Google Cloud project ID to use for resources"
  type        = string
}

variable "environment" {
  description = "Environment tag to help identify the entire deployment"
  type        = string
}

variable "region" {
  description = "The GCP region to create and test resources in"
  type        = string
  default     = "us-central1"
}

variable "labels" {
  type        = map(any)
  description = "Labels, provided as a map"
  default     = {}
}

# -------------------------------------------------------------------
# Developer Configuration
# -------------------------------------------------------------------

variable "developers_email" {
  description = "User Email address that will use Cloud Workstations"
  type        = list(string)
}

variable "developers_name" {
  description = "User names that will use Cloud Workstations"
  type        = list(string)
}

# -------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "workstations-vpc"
}

variable "subnetwork_range" {
  description = "The range of internal addresses that are owned by this subnetwork."
  type        = string
  default     = "10.2.0.0/16"
}

# -------------------------------------------------------------------
# Service Account Configuration
# -------------------------------------------------------------------

variable "service_account_id" {
  description = "Service account ID for workstations"
  type        = string
  default     = "cloud-workstations-sa"
}

# -------------------------------------------------------------------
# Artifact Registry Configuration
# -------------------------------------------------------------------

variable "artifact_repo_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "workstations-vscode"
}

# -------------------------------------------------------------------
# Workstation Cluster Configuration
# -------------------------------------------------------------------

variable "workstation_cluster_name" {
  description = "Name of the workstation cluster"
  type        = string
  default     = "tf-ws-cluster"
}

variable "workstation_config_name" {
  description = "Name of the workstation configuration"
  type        = string
  default     = "tf-ws-config"
}

# -------------------------------------------------------------------
# Compute Configuration
# -------------------------------------------------------------------

variable "machine_type" {
  description = "Machine type for workstation VMs"
  type        = string
  default     = "e2-standard-4"
}

# -------------------------------------------------------------------
# Persistent Disk Configuration
# -------------------------------------------------------------------

variable "persistent_disk_size_gb" {
  description = "Size of persistent disk for workstation home directory (GB)"
  type        = number
  default     = 200
}

variable "persistent_disk_type" {
  description = "Type of persistent disk (pd-ssd, pd-balanced, pd-standard)"
  type        = string
  default     = "pd-ssd"
}

variable "persistent_disk_reclaim_policy" {
  description = "Reclaim policy for persistent disk (DELETE or RETAIN)"
  type        = string
  default     = "DELETE"
}

# -------------------------------------------------------------------
# Workstation Timeout Configuration
# -------------------------------------------------------------------

variable "idle_timeout" {
  description = "Duration after which a workstation will be stopped if idle (e.g., '7200s' for 2 hours). Set to null to disable."
  type        = string
  default     = "7200s"  # 2 hours
}

variable "running_timeout" {
  description = "Maximum duration a workstation can run (e.g., '43200s' for 12 hours). Set to null to disable."
  type        = string
  default     = "43200s"  # 12 hours
}

# -------------------------------------------------------------------
# API Timing Configuration
# -------------------------------------------------------------------

variable "api_activation_wait" {
  description = "Duration to wait after enabling APIs (e.g., '30s')"
  type        = string
  default     = "30s"
}

variable "org_policy_wait" {
  description = "Duration to wait after setting organization policies (e.g., '60s')"
  type        = string
  default     = "60s"
}

# -------------------------------------------------------------------
# Cloud Build Configuration
# -------------------------------------------------------------------

variable "schedule_container_rebuilds" {
  description = "Enable Cloud Build trigger and Cloud Scheduler for scheduled container rebuilds"
  type        = bool
  default     = false
}

variable "github_repo_owner" {
  description = "GitHub repository owner (username or organization)"
  type        = string
  default     = "jbrache"
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type        = string
  default     = "cloud-workstations"
}

variable "container_rebuild_schedule" {
  description = "Cron schedule for container image rebuilds (e.g., '0 0 * * 0' for evry sunday at 12am UTC)"
  type        = string
  default     = "0 0 * * 0"  # At 00:00 on Sunday UTC
}
