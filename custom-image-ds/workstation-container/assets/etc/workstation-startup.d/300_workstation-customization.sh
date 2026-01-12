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

# ----------------------------------------
# VS Code
# ----------------------------------------
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
export PATH="/opt/workstation/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export ZSH=/opt/workstation/oh-my-zsh
export ZSH_THEME="powerlevel10k/powerlevel10k"
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=True

# Claude Code setup
# Only export these if they are already present in the environment
if [ -n "$CLAUDE_CODE_USE_VERTEX" ] && \
   [ -n "$CLOUD_ML_REGION" ] && \
   [ -n "$ANTHROPIC_VERTEX_PROJECT_ID" ]; then
    export CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX
    export CLOUD_ML_REGION=$CLOUD_ML_REGION
    export ANTHROPIC_VERTEX_PROJECT_ID=$ANTHROPIC_VERTEX_PROJECT_ID
fi

# Gemini setup
# Only export these if they are already present in the environment
if [ -n "$GOOGLE_GENAI_USE_VERTEXAI" ] && \
   [ -n "$GOOGLE_CLOUD_LOCATION" ] && \
   [ -n "$GOOGLE_CLOUD_PROJECT" ]; then
    export GOOGLE_GENAI_USE_VERTEXAI=$GOOGLE_GENAI_USE_VERTEXAI
    export GOOGLE_CLOUD_LOCATION=$GOOGLE_CLOUD_LOCATION
    export GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
fi

# Disable auto-activation (if you prefer manual control)
VIRTUAL_ENV_DISABLE_PROMPT=true

# Change virtualenv indicator in prompt
ZSH_THEME_VIRTUALENV_PREFIX="("
ZSH_THEME_VIRTUALENV_SUFFIX=")"

plugins=(
    git
    zsh-autosuggestions
    kubectl
    python
    pip
    virtualenv
)

POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status virtualenv)

alias tf='terraform'
alias kc='kubectl'
alias code='code-oss-cloud-workstations'

source "$ZSH/oh-my-zsh.sh"
EOF
chsh -s $(which zsh) ${username}
fi

zsh -c "source  $ZSH/oh-my-zsh.sh"

chown -R ${username}:${username} /home/${username}
# chown -R ${username}:${username} /opt/workstation
# chmod -R 755 /opt/workstation
chown -R ${username}:${username} /opt
chmod -R 755 /opt

# ----------------------------------------
# CLI Tools
# ----------------------------------------
TARGET_HOME="/home/${username}"
# Ensure the standard local bin directory exists
mkdir -p "$TARGET_HOME/.local/bin"

# ----------------------------------------
# [Skip] Node: Should be installed in base image
# ----------------------------------------

# ----------------------------------------
# [Optional] Chrome Remote Desktop & Chrome
# ----------------------------------------
# Chrome Remote Desktop
# wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

# Chrome
# wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# ----------------------------------------
# uv
# ----------------------------------------
EXPECTED_BIN="$TARGET_HOME/.local/bin/uv"

echo "Checking for uv installation..."

# 1. Condition: Only run if the binary does NOT exist
if [ ! -f "$EXPECTED_BIN" ]; then
    echo "uv not found at $EXPECTED_BIN. Starting installation..."

    # 2. Execute the installer with the hijacked HOME variable
    # We use 'env' to ensure the variable is exported correctly to the subshell
    if curl -LsSf https://astral.sh/uv/install.sh | HOME="$TARGET_HOME" sh; then
        echo "Successfully installed uv to $TARGET_HOME"
    else
        echo "Error: Installation script failed."
        exit 1
    fi
else
    echo "uv is already installed at $EXPECTED_BIN. Skipping installation."
fi

# ----------------------------------------
# Claude
# ----------------------------------------
EXPECTED_BIN="$TARGET_HOME/.local/bin/claude"

echo "Checking for Claude installation..."

# 1. Condition: Only run if the binary does NOT exist
if [ ! -f "$EXPECTED_BIN" ]; then
    echo "Claude not found at $EXPECTED_BIN. Starting installation..."

    # 2. Execute the installer with the hijacked HOME variable
    # We use 'env' to ensure the variable is exported correctly to the subshell
    if curl -fsSL https://claude.ai/install.sh | HOME="$TARGET_HOME" bash; then
        echo "Successfully installed Claude to $TARGET_HOME"
    else
        echo "Error: Installation script failed."
        exit 1
    fi
else
    echo "Claude is already installed at $EXPECTED_BIN. Skipping installation."
fi

# ----------------------------------------
# Goose
# ----------------------------------------
EXPECTED_BIN="$TARGET_HOME/.local/bin/goose"

echo "Checking for Goose installation..."

# 1. Condition: Only run if the binary does NOT exist
if [ ! -f "$EXPECTED_BIN" ]; then
    echo "Goose not found at $EXPECTED_BIN. Starting installation..."

    # 2. Execute the installer with the hijacked HOME variable
    # We use 'env' to ensure the variable is exported correctly to the subshell
    if curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false HOME="$TARGET_HOME" bash; then
        echo "Successfully installed Goose to $TARGET_HOME"
    else
        echo "Error: Installation script failed."
        exit 1
    fi
else
    echo "Goose is already installed at $EXPECTED_BIN. Skipping installation."
fi

# ----------------------------------------
# Final Path Verification & Permissions
# ----------------------------------------
# Use -d to check if the directory exists
if [ -d "/home/${username}/.local/bin" ]; then
    # Make sure all binaries inside the directory are executable
    chmod -R +x "/home/${username}/.local/bin"
    
    # Check if the path is in the current session's PATH
    if [[ ":$PATH:" != *":/home/${username}/.local/bin:"* ]]; then
        echo "Tip: Add '/home/${username}/.local/bin' to your PATH to run installed CLI tools from anywhere."
    fi
fi

# Secure SSH directory if it exists
if [ -d "/home/${username}/.ssh" ]; then
    chmod 700 /home/${username}/.ssh
    chmod 600 /home/${username}/.ssh/*
fi

chown -R ${username}:${username} /home/${username}

# ----------------------------------------
# MCP Server Registration
# ----------------------------------------
# Run the MCP addition as the specific user
# -i ensures the login environment is simulated so 'uvx' can be found in the PATH
sudo -i -u "${username}" bash -c "claude mcp add adk-docs --transport stdio -- uvx --from mcpdoc mcpdoc --urls AgentDevelopmentKit:https://google.github.io/adk-docs/llms.txt --transport stdio"
