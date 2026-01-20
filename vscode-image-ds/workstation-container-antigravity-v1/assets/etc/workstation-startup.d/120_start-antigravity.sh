#!/bin/bash
#
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

# Startup script to start Antigravity IDE using the REH (Remote Extension Host) bundle.
#
# If the Antigravity process exits, this script will attempt to shutdown the
# container by killing all other processes.

# Having some issues with this so exit out
echo "Skip starting Antigravity web server with 'serve-web'"
exit 1

echo "Starting Antigravity web server with 'serve-web'"

source /etc/profile.d/go_envs.sh

export EDITOR_PORT=80
# export PATH="$PATH:/opt/vscode/code"
DEFAULT_USER="user"

# Antigravity REH bundle configuration
ANTIGRAVITY_VERSION="1.13.3-94f91bc110994badc7c086033db813077a5226af"
ANTIGRAVITY_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${ANTIGRAVITY_VERSION}/linux-x64/Antigravity-reh.tar.gz"
# ANTIGRAVITY_INSTALL_DIR="/opt/antigravity-server"

# Check if the environment variable is set and not empty
if [ -n "${OSLOGIN_USER}" ]; then
  # Use the value of the environment variable
  username=$(echo "$OSLOGIN_USER" | sed 's/[@.]/_/g')
  echo "Attempting to use username derived from 'OSLOGIN_USER': '${username}'"
  # Check if the user already exists
  if id -u "${username}" &>/dev/null; then
    echo "User '${username}' exists."
  else
    echo "User '${username}' derived from 'OSLOGIN_USER' does not exist."
    echo "Falling back to default user: '${DEFAULT_USER}'."
    username="$DEFAULT_USER"
  fi
else
  # Use the default username
  username="$DEFAULT_USER"
  echo "Environment variable 'OSLOGIN_USER' is not set or is empty. Using default username '${username}'."
fi

export HOME="/home/${username}"
# Attempt to source .bashrc, be cautious if it doesn't exist
if [ -f "${HOME}/.bashrc" ]; then
  source "${HOME}/.bashrc"
else
  echo "Warning: ${HOME}/.bashrc not found."
fi

# Install Antigravity REH bundle if not already installed
if [ ! -f "/usr/bin/antigravity-server-download" ]; then
  echo "Installing Antigravity REH bundle..."
  
  # Create installation directory
  mkdir -p "/usr/bin/antigravity-download"
  
  # Download and extract the REH bundle
  echo "Downloading Antigravity REH bundle..."
  curl -fsSL "${ANTIGRAVITY_URL}" -o /tmp/antigravity-reh.tar.gz
  tar -xzf /tmp/antigravity-reh.tar.gz -C "/usr/bin/antigravity-server-download"
  rm -f /tmp/antigravity-reh.tar.gz
  
  # Make binaries executable
  chmod -R +x "/usr/bin"
  
  # Create symlink for antigravity-tunnel command
  mkdir -p /usr/share/antigravity/bin/
  ln -sf "/usr/bin/antigravity-server-download/bin/antigravity-server" /usr/share/antigravity/bin/antigravity-tunnel
  
  echo "Antigravity REH bundle installed successfully."
fi

function start_antigravity {
  echo "Starting Antigravity as user '${username}' with HOME='${HOME}'"
  runuser "${username}" -c -l "cd /usr/bin && antigravity serve-web --host 0.0.0.0 --port=${EDITOR_PORT} --without-connection-token"
}

function kill_container {
  echo "Antigravity exited, terminating container."
  ps x | awk {'{print $1}'} | awk 'NR > 1' | xargs kill
}

(start_antigravity || kill_container)&
