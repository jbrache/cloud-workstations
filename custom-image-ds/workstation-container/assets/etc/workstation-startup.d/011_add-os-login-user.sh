#!/bin/bash
#
# Copyright 2022 Google Inc. All Rights Reserved.
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
# Startup script to add OS Login user to workstation container.
#

# Define the default username
DEFAULT_USER="user"

create_posix_user_from_os_login() {
  local groups
  local profile_data
  local username
  local uid
  local gid
  local home_dir

  groups=docker,sudo,users
  if [ ${CLOUD_WORKSTATIONS_CONFIG_DISABLE_SUDO:-false} == "true" ]; then
    groups=docker
  fi

  # Check if the environment variable is set and not empty
  if [ -n "${OSLOGIN_USER}" ]; then
    # Use the value of the environment variable
    username=$(echo "${OSLOGIN_USER}" | sed 's/[@.]/_/g')
    echo "Environment variable 'OSLOGIN_USER' is set to '${OSLOGIN_USER}'."
    echo "Setting the username to '${username}'."
  else
    # Use the default username
    username="${DEFAULT_USER}"
    echo "Environment variable 'OSLOGIN_USER' is not set or is empty. Using default username '${username}'."
  fi

  # Check if the user already exists
  if id -u "${username}" &>/dev/null; then
    echo "User '${username}' already exists."
  else
    # Create the user
    if [ -n "${OSLOGIN_USER}" ]; then
      profile_data=$(curl -s "http://metadata.google.internal/computeMetadata/v1/oslogin/users?username=${username}" -H "Metadata-Flavor: Google" | jq -r ".loginProfiles[0].posixAccounts[0]")
      username=$(echo "${profile_data}" | jq -r '.username')
      uid=$(echo "${profile_data}" | jq -r '.uid')
      gid=$(echo "${profile_data}" | jq -r '.gid')
      # home_dir=$(echo "${profile_data}" | jq -r '.homeDirectory')
      home_dir="/home/${username}"

      echo "Extracted User Info:"
      echo "  Username: ${username}"
      echo "  UID:      ${uid}"
      echo "  GID:      ${gid}"
      echo "  Home Directory: ${home_dir}"

      echo "Creating group '${gid}"
      sudo groupadd -g "$gid" "$username"

      echo "Creating user '${username}'..."
      sudo useradd -m -d "$home_dir" -u "$uid" -g "$gid" -G $groups --shell /bin/bash "${username}"
    else
      echo "Creating user '${username}'..."
      sudo useradd -m "${username}" -G $groups --shell /bin/bash > /dev/null
    fi

    # Check if the user was created successfully
    if [ $? -eq 0 ]; then
      echo "User '${username}' created successfully."
    else
      echo "Failed to create user '${username}'." >&2
      exit 1
    fi

    # Setting an empty password for user
    sudo passwd -d "${username}" >/dev/null
    # echo "%sudo ALL=NOPASSWD: ALL" >> /etc/sudoers
  fi

  exit 0
}

echo "Creating a user based on 'OSLOGIN_USER' environment variable..."
create_posix_user_from_os_login
result=$?
if [ $result -eq 0 ]; then
  echo "User created successfully"
else
  echo "User creation failed"
fi