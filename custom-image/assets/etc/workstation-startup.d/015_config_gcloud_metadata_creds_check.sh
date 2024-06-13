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

function configureMetadataCredsCheck {

  TRIGGER=$1 # timer or /etc/passwd

  # get list of root (id=0) and non-root users (100<=id<65534)
  USERS="root $(awk -F ':' '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)"

  # if service account enabled by env var, delete flag file
  # otherwise set flag to False to disable service account
  for USER in $USERS; do
    sudo -u $USER /bin/bash -c '
      if [ ${CLOUD_WORKSTATIONS_ENABLE_METADATA_CREDS_CHECK:-false} == "true" ]; then
        echo "gcloud metadata creds check enabled for $(whoami) ('$TRIGGER')"
        rm -f $HOME/.config/gcloud/gce
      else
        echo "gcloud metadata creds check disabled for $(whoami) ('$TRIGGER')"
        mkdir -p $HOME/.config/gcloud
        echo False > $HOME/.config/gcloud/gce
      fi
    '
  done
}

# Continually update since the file expires
# do loop in background so startup can continue
while true
do
  configureMetadataCredsCheck timer
  sleep 5m
done &

# also trigger reconfiguration when /etc/passwd changes - using deletion of lock
# file as trigger signal - this should apply config e.g. to new users even
# before first login
inotifywait -mq /etc/ | grep --line-buffered "DELETE passwd.lock" | while read -r LINE;
do
  configureMetadataCredsCheck /etc/passwd
done &

