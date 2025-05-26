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

DEFAULT_USER="user"

# Check if the environment variable is set and not empty
if [ -n "${ACCOUNT}" ]; then
  # Use the value of the environment variable
  username=$(echo "$ACCOUNT" | sed 's/[@.]/_/g')
  echo "Attempting to use username derived from 'ACCOUNT': '${username}'"
  # Check if the user already exists
  if id -u "${username}" &>/dev/null; then
    echo "User '${username}' exists."
  else
    echo "User '${username}' derived from 'ACCOUNT' does not exist."
    echo "Falling back to default user: '${DEFAULT_USER}'."
    username="$DEFAULT_USER"
  fi
else
  # Use the default username
  username="$DEFAULT_USER"
  echo "Environment variable 'ACCOUNT' is not set or is empty. Using default username '${username}'."
fi

VSCODE_PATH="/home/${username}/.vscode-server"
SETTINGS_PATH="$VSCODE_PATH/data/Machine"

mkdir -p $SETTINGS_PATH
cat << EOF > $SETTINGS_PATH/settings.json
{
    "workbench.colorTheme": "Default Dark+",
    "terminal.integrated.defaultProfile.linux": "zsh",
}
EOF

chown -R $username:$username $VSCODE_PATH
chmod -R 755 $VSCODE_PATH

# ----------------------------------------
# Oh My zsh
# ----------------------------------------
export ZSH=/opt/workstation/oh-my-zsh

if [ -f "/home/${username}/.zshrc" ]; then
    echo "ZSH already configured"
else

    cat << 'EOF' > /home/${username}/.zshrc
export PATH="$PATH:/opt/workstation/bin"

export ZSH=/opt/workstation/oh-my-zsh
export ZSH_THEME="powerlevel10k/powerlevel10k"
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=True

plugins=(
    git
    zsh-autosuggestions
    kubectl
)

alias tf='terraform'
alias kc='kubectl'
alias code='code-oss-cloud-workstations'

source "$ZSH/oh-my-zsh.sh"
EOF
chsh -s $(which zsh) ${username}
fi

zsh -c "source  $ZSH/oh-my-zsh.sh"

chown -R ${username}:${username} /home/${username}
chown -R ${username}:${username} /opt/workstation
chmod -R 755 /opt/workstation