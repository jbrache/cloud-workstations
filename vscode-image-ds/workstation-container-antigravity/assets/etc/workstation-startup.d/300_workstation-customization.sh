#!/bin/bash
#
# Copyright 2026 Google LLC
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

# Exit on error, undefined variable, and pipe failures
set -euo pipefail

DEFAULT_USER="user"

# ----------------------------------------
# Helper Functions
# ----------------------------------------

# Install a CLI tool using a remote installer script
# Usage: install_cli_tool <name> <binary_path> <install_command>
install_cli_tool() {
    local name="$1"
    local expected_bin="$2"
    local install_cmd="$3"

    echo "Checking for ${name} installation..."

    if [ ! -f "$expected_bin" ]; then
        echo "${name} not found at ${expected_bin}. Starting installation..."
        if eval "$install_cmd"; then
            echo "Successfully installed ${name}"
        else
            echo "Warning: ${name} installation failed. Continuing..."
            return 1
        fi
    else
        echo "${name} is already installed at ${expected_bin}. Skipping installation."
    fi
    return 0
}

# ----------------------------------------
# Determine Username
# ----------------------------------------

# Check if the environment variable is set and not empty
if [ -n "${OSLOGIN_USER:-}" ]; then
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

TARGET_HOME="/home/${username}"

# ----------------------------------------
# Oh My Zsh Configuration
# ----------------------------------------
export ZSH=/opt/workstation/oh-my-zsh

if [ -f "${TARGET_HOME}/.zshrc" ]; then
    echo "ZSH already configured"
else
    cat << 'EOF' > "${TARGET_HOME}/.zshrc"
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
# alias code='code-oss-cloud-workstations'

source "$ZSH/oh-my-zsh.sh"
EOF
    chsh -s "$(which zsh)" "${username}"
fi

# Set workstation directory ownership
chown -R "${username}:${username}" /opt/workstation
chmod -R 755 /opt/workstation

# ----------------------------------------
# CLI Tools Installation
# ----------------------------------------

# Ensure the standard local bin directory exists
mkdir -p "${TARGET_HOME}/.local/bin"

# ----------------------------------------
# [Skip] Node: Should be installed in base image
# ----------------------------------------

# ----------------------------------------
# [Optional] Chrome Remote Desktop & Chrome
# ----------------------------------------
# Need to add

# ----------------------------------------
# Install CLI Tools using helper function
# ----------------------------------------

# uv - Python package manager
install_cli_tool "uv" \
    "${TARGET_HOME}/.local/bin/uv" \
    "curl -LsSf https://astral.sh/uv/install.sh | HOME='${TARGET_HOME}' sh" || true

# Claude Code
install_cli_tool "Claude" \
    "${TARGET_HOME}/.local/bin/claude" \
    "curl -fsSL https://claude.ai/install.sh | HOME='${TARGET_HOME}' bash" || true

# Goose
install_cli_tool "Goose" \
    "${TARGET_HOME}/.local/bin/goose" \
    "curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false HOME='${TARGET_HOME}' bash" || true

# ----------------------------------------
# Final Permissions
# ----------------------------------------

# Make all binaries in .local/bin executable
if [ -d "${TARGET_HOME}/.local/bin" ]; then
    chmod -R +x "${TARGET_HOME}/.local/bin"
    
    # Inform user about PATH
    if [[ ":$PATH:" != *":${TARGET_HOME}/.local/bin:"* ]]; then
        echo "Tip: Add '${TARGET_HOME}/.local/bin' to your PATH to run installed CLI tools from anywhere."
    fi
fi

# Secure SSH directory if it exists
if [ -d "${TARGET_HOME}/.ssh" ]; then
    chmod 700 "${TARGET_HOME}/.ssh"
    # Only change permissions on files if they exist
    find "${TARGET_HOME}/.ssh" -type f -exec chmod 600 {} \; 2>/dev/null || true
fi

# Final ownership fix for user home directory
chown -R "${username}:${username}" "${TARGET_HOME}"

# ----------------------------------------
# MCP Server Registration
# ----------------------------------------
CLAUDE_BIN="${TARGET_HOME}/.local/bin/claude"

if [ -f "$CLAUDE_BIN" ]; then
    sudo -u "${username}" bash -c "${CLAUDE_BIN} mcp add adk-docs --scope user --transport stdio -- uvx --from mcpdoc mcpdoc --urls AgentDevelopmentKit:https://google.github.io/adk-docs/llms.txt --transport stdio" || true
    # claude mcp add --transport http paypal https://mcp.paypal.com/mcp
    # claude mcp add --transport sse square https://mcp.squareup.com/sse
    # claude mcp add --transport http stripe https://mcp.stripe.com
fi

echo "Workstation customization complete."
