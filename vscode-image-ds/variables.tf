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

variable "zone" {
  description = "The GCP zone to create the instance in"
  type        = string
  default     = "us-central1-a"
}

variable "dnszone" {
  description = "The Private DNS zone to resolve private storage api"
  type        = string
  default     = "private.googleapis.com."
}

variable "subnetwork_range" {
  description = "The range of internal addresses that are owned by this subnetwork."
  type        = string
  default     = "10.2.0.0/16"
}

variable "machine_type" {
  description = "Machine type to application"
  type        = string
  default     = "e2-standard-4"
}

variable "install_gpu_driver" {
  description = "Install GPU drivers"
  type        = string
  default     = false
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  default     = "200"
}

variable "boot_disk_type" {
  description = "Boot disk type, can be either pd-ssd, local-ssd, or pd-standard"
  default     = "PD_STANDARD"
}

variable "data_disk_size_gb" {
  description = "The size of the disk in GB attached to this VM instance, up to a maximum of 64000 GB (64 TB). If not specified, this defaults to 100."
  default     = "100"
}

variable "data_disk_type" {
  description = "Indicates the type of the disk. Possible values are: PD_STANDARD, PD_SSD, PD_BALANCED, PD_EXTREME."
  default     = "PD_STANDARD"
}

variable "can_ip_forward" {
  description = "Enable IP forwarding, for NAT instances for example"
  type        = string
  default     = "false"
}

variable "labels" {
  type        = map(any)
  description = "Labels, provided as a map"
  default     = {}
}


variable "instance_owners" {
  description = "User Email address that will own Vertex Workbench"
  type        = list(any)
}

variable "developers_email" {
  description = "User Email address that will use Cloud Workstations"
  type        = list(any)
}

variable "developers_name" {
  description = "User names that will use Cloud Workstations"
  type        = list(any)
}

