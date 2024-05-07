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

# CODEOSS_PATH="/home/user/.codeoss-cloudworkstations"
# SETTINGS_PATH="$CODEOSS_PATH/data/Machine"

# mkdir -p $SETTINGS_PATH
# cat << EOF > $SETTINGS_PATH/settings.json
# {
#     "workbench.colorTheme": "Default Dark+",
#     "terminal.integrated.defaultProfile.linux": "zsh"
# }
# EOF

# chown -R user:user $CODEOSS_PATH
# chmod -R 755 $CODEOSS_PATH

export ZSH=/opt/workstation/oh-my-zsh

if [ -f "/home/user/.zshrc" ]; then
    echo "ZSH already configured"
else

    cat << 'EOF' > /home/user/.zshrc
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
chsh -s $(which zsh) user
fi

zsh -c "source  $ZSH/oh-my-zsh.sh"

chown -R user:user /home/user
chown -R user:user /opt/workstation
chmod -R 755 /opt/workstation