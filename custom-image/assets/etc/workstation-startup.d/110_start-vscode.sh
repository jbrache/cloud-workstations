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

# Startup script to start Code OSS.
#
# If the Code OSS process exits, this script will attempt to shutdown the
# container by killing all other processes.

echo "Starting VS Code"

source /etc/profile.d/go_envs.sh

export HOME=/home/user
export EDITOR_PORT=80
export PATH="$PATH:/opt/vscode/code"

source ~/.bashrc

function start_vscode {
  runuser user -c -l "cd /opt/vscode/ && ./code serve-web --host 0.0.0.0 --port=${EDITOR_PORT} --without-connection-token"
}

function kill_container {
  echo "VS Code exited, terminating container."
  ps x | awk {'{print $1}'} | awk 'NR > 1' | xargs kill
}

(start_vscode || kill_container)&