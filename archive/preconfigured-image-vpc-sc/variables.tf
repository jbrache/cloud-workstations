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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "policy_name" {
  description = "The policy's name."
  type        = string
  default     = "Cloud Workstations VPC-SC Policy"
}

variable "folder_id" {
  description = "The folder to deploy project in"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "project_name" {
  description = "Prefix of Google Project name"
  type        = string
  default = "prj"
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

# variable "gpu_type" {
#   description = "GPU Type"
#   type        = string
#   default     = "NVIDIA_TESLA_T4"
# }

# variable "gpu_core_count" {
#   description = "Count of cores of the accelerator"
#   type        = string
#   default     = 1
# }

# variable "install_gpu_driver" {
#   description = "Install GPU drivers"
#   type        = string
#   default     = false
# }

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

variable "workstations_container_image" {
  description = "Image to use for Cloud Workstations. By default uses Cloud Workstations base editor, Code OSS for Cloud Workstations, based on Code-OSS."
  type        = string
  default     = "us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest"
}

variable "access_policy_admin_email" {
  description = "User Email address that will administrat VPC-SC Access Policy"
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
