#!/bin/bash
#
# Copyright 2024 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# adapted from /etc/profile.d/disable_gcloud_gce_check.sh
# to handle multiple users and non-sudoers
#
# the base image's original file is replaced with a simplified
# version since polling is now handled here

# get list of root (id=0) and non-root users (100<=id<65534)
USERS="root $(awk -F ':' '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)"

function disableMetadataCredsCheck {
  # set gce flag to False
  echo "disabling gcloud metadata creds check"
  for USER in $USERS; do
    su - $USER bash -c '
      mkdir -p $HOME/.config/gcloud 2> /dev/null
      echo False > $HOME/.config/gcloud/gce 2> /dev/null
    '
  done
}

if [ ${CLOUD_WORKSTATIONS_ENABLE_METADATA_CREDS_CHECK:-false} == "true" ]; then
  # remove flag in case env has changed since previous start
  echo "enabling gcloud metadata creds check"
  for USER in $USERS; do
    su - $USER bash -c '
      rm -f $HOME/.config/gcloud/gce 2> /dev/null
    '
  done
else
  # do this once synchronously before continuing with startup
  disableMetadataCredsCheck
  # Continually update since the file expires
  # do loop in background so startup can continue
  while true
  do
    sleep 5m
    disableMetadataCredsCheck
  done &
fi

