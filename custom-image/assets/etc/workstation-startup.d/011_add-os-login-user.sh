#!/bin/bash
#
# Copyright 2025 Google Inc. All Rights Reserved.
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
# Startup script to add authenticated OS Login user to workstation container.
#

# useradd -m user -G $groups --shell /bin/bash > /dev/null
# passwd -d user >/dev/null
# echo "%sudo ALL=NOPASSWD: ALL" >> /etc/sudoers

# This command is run as the default user 'user' in the container.
# sudo -H -u user bash -c "cd ~; <your_bash_commands>"

create_posix_user_from_gcloud() {
  local gropus
  groups=docker,sudo,users
  if [ ${CLOUD_WORKSTATIONS_CONFIG_DISABLE_SUDO:-false} == "true" ]
  then
  groups=docker
  fi

  # 1. Get the OS Login profile data
  echo "Fetching OS Login profile..."
  local profile_data
  profile_data=$(sudo -H -u user bash -c "cd ~; gcloud compute os-login describe-profile --format=\"value(posixAccounts)\"")

  # Check if gcloud command was successful and output is not empty
  if [[ -z "$profile_data" ]]; then
    echo "Error: Failed to retrieve OS Login profile or profile is empty." >&2
    return 1
  fi

  # 2. Parse the data
  # The output is a string representation of a Python dictionary.
  # This example uses grep and cut. For more robust parsing, consider jq or Python.
  echo "Parsing profile data: $profile_data"

  local gid
  gid=$(sudo -H -u user bash -c "cd ~; gcloud compute os-login describe-profile --format=\"value(posixAccounts.gid)\"")
  local home_dir
  home_dir=$(sudo -H -u user bash -c "cd ~; gcloud compute os-login describe-profile --format=\"value(posixAccounts.homeDirectory)\"")
  local uid
  uid=$(sudo -H -u user bash -c "cd ~; gcloud compute os-login describe-profile --format=\"value(posixAccounts.uid)\"")
  local username
  username=$(sudo -H -u user bash -c "cd ~; gcloud compute os-login describe-profile --format=\"value(posixAccounts.username)\"")

  # Validate extracted values
  if [[ -z "$gid" || -z "$home_dir" || -z "$uid" || -z "$username" ]]; then
    echo "Error: Failed to parse all required fields from profile data." >&2
    echo "GID: '$gid', Home: '$home_dir', UID: '$uid', Username: '$username'" >&2
    return 1
  fi

  echo "Extracted User Info:"
  echo "  Username: $username"
  echo "  UID:      $uid"
  echo "  GID:      $gid"
  echo "  Home Dir: $home_dir"

  # 3. Create the group if it doesn't exist (based on GID)
  # This is important even if the user exists, as the group might be shared or missing.
  if ! getent group "$gid" > /dev/null; then
    echo "Creating group (name derived from username for convenience: $username) with GID $gid..."
    # Attempt to use the username as the group name if that name isn't taken,
    # otherwise use a generic g<gid> name.
    local group_name_to_create="$username"
    if getent group "$group_name_to_create" > /dev/null; then
        # if username as group name already exists (and is not for our target gid)
        # then we need a different group name.
        if [[ "$(getent group "$group_name_to_create" | cut -d: -f3)" != "$gid" ]]; then
            group_name_to_create="g$gid" # fallback group name
            echo "Warning: Group name '$username' already exists with a different GID. Will attempt to create group '$group_name_to_create'."
            if getent group "$group_name_to_create" > /dev/null; then
                 # if even g<gid> is taken by a different gid, this is an issue
                 if [[ "$(getent group "$group_name_to_create" | cut -d: -f3)" != "$gid" ]]; then
                    echo "Error: Fallback group name '$group_name_to_create' also exists with a different GID. Cannot create group for GID $gid." >&2
                    return 1
                 fi
            fi
        fi
    fi

    if sudo groupadd -g "$gid" "$group_name_to_create"; then
      echo "Group $group_name_to_create (GID: $gid) created successfully."
    else
      # Check if the group with GID $gid was created by someone else in a race condition
      # or if groupadd failed for another reason.
      if getent group "$gid" > /dev/null; then
        local actual_group_name=$(getent group "$gid" | cut -d: -f1)
        echo "Info: Group with GID $gid ($actual_group_name) seems to exist now. Proceeding."
      else
        echo "Error: Failed to create group for GID $gid (tried name: $group_name_to_create)." >&2
        return 1
      fi
    fi
  else
    local existing_group_name
    existing_group_name=$(getent group "$gid" | cut -d: -f1)
    echo "Group with GID $gid ($existing_group_name) already exists. Skipping group creation."
  fi

  # 4. Create the user IF THE USER DOES NOT ALREADY EXIST
  if ! id -u "$username" > /dev/null 2>&1; then
    echo "Creating user $username with UID $uid, GID $gid, and home $home_dir..."
    # -m: create home directory
    # -d: specify home directory path
    # -u: specify UID
    # -g: specify primary GID
    # -s: specify shell (optional, e.g., -s /bin/bash)
    # Using --no-user-group by default as we manage group creation separately by GID.
    # However, if the group name matches username and has the correct GID, it's fine.
    # Ensure the group GID from gcloud is used as the primary group.
    # if sudo useradd -m -d "$home_dir" -u "$uid" -g "$gid" "$username"; then
    if sudo useradd -m -d "$home_dir" -u "$uid" -g "$gid" -G $groups --shell /bin/bash "$username"; then
      echo "User $username created successfully."

      # Setting an empty password for user
      sudo passwd -d "$username" >/dev/null

      # 5. Ensure home directory ownership and permissions
      # (useradd -m should handle this, but we can be explicit)
      if [[ -d "$home_dir" ]]; then
        echo "Verifying home directory ownership and permissions for $home_dir..."
        # Ensure ownership is UID:GID from gcloud, not username:groupname if they differ
        # and the GID is the numeric GID.
        if sudo chown "$uid:$gid" "$home_dir" && sudo chmod 700 "$home_dir"; then
            echo "Home directory ownership and permissions set correctly for $username."
        else
            echo "Warning: Failed to fully set ownership/permissions on $home_dir for $username. Please check manually." >&2
        fi
      else
        echo "Warning: Home directory $home_dir was not created by useradd for $username. Please check manually." >&2
      fi
    else
      echo "Error: Failed to create user $username." >&2
      # It's possible the UID is taken, even if the username isn't. useradd should report this.
      if id -nu "$uid" > /dev/null 2>&1 && [[ "$(id -un "$uid")" != "$username" ]]; then
        local existing_user_with_uid
        existing_user_with_uid=$(id -un "$uid")
        echo "Error: UID $uid is already in use by user '$existing_user_with_uid'." >&2
      fi
      return 1
    fi
  else
    # This block is executed if the user already exists.
    local existing_uid
    existing_uid=$(id -u "$username")
    echo "User '$username' (UID: $existing_uid) already exists. Skipping user creation."
    # Optionally, you could add checks here to see if the existing user's UID/GID/Home matches
    # the gcloud profile, and warn if they don't, but the request was just to skip.
    # For example:
    if [[ "$existing_uid" != "$uid" ]]; then
        echo "Warning: Existing user '$username' has UID $existing_uid, but gcloud profile specifies UID $uid." >&2
    fi
    local existing_gid
    existing_gid=$(id -g "$username")
    if [[ "$existing_gid" != "$gid" ]]; then
        echo "Warning: Existing user '$username' has GID $existing_gid, but gcloud profile specifies GID $gid." >&2
    fi
    local existing_home_dir
    existing_home_dir=$(getent passwd "$username" | cut -d: -f6)
    if [[ "$existing_home_dir" != "$home_dir" ]]; then
        echo "Warning: Existing user '$username' has home directory '$existing_home_dir', but gcloud profile specifies '$home_dir'." >&2
    fi
  fi

  echo "POSIX user setup process complete for $username."
  return 0
}

# --- Main loop to run the function until successful ---
attempts=0
while true; do
  ((attempts++))
  echo "--- Attempt #$attempts to run user setup script at $(date) ---"
  
  create_posix_user_from_gcloud # Call the function

  if [[ $? -eq 0 ]]; then
    echo "--- Script completed successfully on attempt #$attempts at $(date)! User setup process finished. ---"
    break # Exit the loop on success
  else
    echo "--- Script failed on attempt #$attempts at $(date). Retrying in 60 seconds... ---"
    sleep 60
  fi
done &

echo "Exiting retry loop."
