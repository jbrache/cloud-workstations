#!/bin/bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PROJECT_ID="[your-project-id]"
export PROJECT_NUMBER="[your-project-number]"
export WORKSTATION_CLUSTER="vscode-cluster"
export WORKSTATION_CONFIG="vscode-config"
export REGION="us-central1"
export SA_NAME="cloud-workstations-sa"
export SA_DESCRIPTION="Email address of the service account that will be used on VM instances used to support the Cloud Workstations config."
export SA_DISPLAY_NAME="cloud-workstations-sa"
export NETWORK_NAME="projects/[your-project-id]/global/networks/[your-network]"
export SUBNETWORK_NAME="projects/[your-project-id]/regions/$REGION/subnetworks/[your-subnetwork]"

gcloud config set project $PROJECT_ID

# ----------------------------------------
# Enable APIs
# ----------------------------------------
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com --project $PROJECT_ID
gcloud services enable workstations.googleapis.com --project $PROJECT_ID

# ----------------------------------------
# Create Custom Container Image
# ----------------------------------------
# https://cloud.google.com/workstations/docs/customize-container-images
gcloud artifacts repositories create default --repository-format=docker \
--location=us-central1 --project $PROJECT_ID

gcloud builds submit . \
--tag="$REGION-docker.pkg.dev/$PROJECT_ID/default/my-workstation-vscode" \
--project $PROJECT_ID

# ----------------------------------------
# Create SA and IAM Bindings
# ----------------------------------------
# https://cloud.google.com/iam/docs/service-accounts-create#gcloud

gcloud iam service-accounts create $SA_NAME \
  --description="$SA_DESCRIPTION" \
  --display-name="$SA_DISPLAY_NAME"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

# ----------------------------------------
# Create Workstations Cluster
# ----------------------------------------
# https://cloud.google.com/sdk/gcloud/reference/workstations/clusters/create

gcloud workstations clusters create $WORKSTATION_CLUSTER \
    --region=$REGION \
    --network=$NETWORK_NAME \
    --subnetwork=$SUBNETWORK_NAME

# ----------------------------------------
# Create Workstations Config
# ----------------------------------------
# https://cloud.google.com/sdk/gcloud/reference/workstations/configs/create

gcloud workstations configs create $WORKSTATION_CONFIG \
    --cluster=$WORKSTATION_CLUSTER \
    --region=$REGION \
    --machine-type=e2-standard-4 \
    --container-custom-image="$REGION-docker.pkg.dev/$PROJECT_ID/default/my-workstation-vscode" \
    --service-account="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --pool-size=0 \
    --pd-disk-type="pd-standard" \
    --pd-disk-size=200

# ----------------------------------------
# Create Workstation
# ----------------------------------------
# https://cloud.google.com/sdk/gcloud/reference/workstations/create
gcloud workstations create vscode-workstation \
    --cluster=$WORKSTATION_CLUSTER \
    --config=$WORKSTATION_CONFIG \
    --region=$REGION