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

FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

ARG DEBIAN_FRONTEND=noninteractive

# ----------------------------------------
# Environment Variables
# ----------------------------------------
ENV VSCODE=/opt/vscode/code
ENV ZSH=/opt/workstation/oh-my-zsh
# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# ----------------------------------------
# System Dependencies & Terraform
# ----------------------------------------
# Consolidated apt installations with proper cleanup
RUN apt-get update && \
    # Add Hashicorp repository for Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    # Install all system packages
    apt-get install -y --no-install-recommends \
        zsh \
        gnupg \
        software-properties-common \
        terraform \
        bzip2 \
        inotify-tools && \
    # Dynamically detect Python version and install venv
    export PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")') && \
    apt-get install -y --no-install-recommends python${PYTHON_VERSION}-venv && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# VS Code Server
# ----------------------------------------
# Single layer: download, extract, cleanup in one command
# Uses detected architecture for proper platform support
RUN arch=$(uname -m) && \
    case "${arch}" in \
        x86_64)  arch="x64" ;; \
        aarch64) arch="arm64" ;; \
        armv7l)  arch="armhf" ;; \
    esac && \
    mkdir -p /opt/vscode && \
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-${arch}" -o /tmp/vscode.tar.gz && \
    tar -xzf /tmp/vscode.tar.gz -C /opt/vscode/ && \
    rm -f /tmp/vscode.tar.gz

# ----------------------------------------
# Oh My Zsh with plugins and theme
# ----------------------------------------
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /opt/workstation/oh-my-zsh/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/workstation/oh-my-zsh/custom/themes/powerlevel10k

# ----------------------------------------
# [Optional] Install k9s
# ----------------------------------------
# RUN curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest \
#     | grep "browser_download_url.*Linux_amd64.tar.gz" \
#     | cut -d : -f 2,3 \
#     | tr -d \" \
#     | wget -qi - && \
#     mkdir -p /opt/workstation/bin && \
#     tar -xf k9s_Linux_amd64.tar.gz -C /opt/workstation/bin && \
#     rm -f k9s_Linux_amd64.tar.gz

# ----------------------------------------
# [Optional] Setup GUI (MATE Desktop)
# ----------------------------------------
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends mate-desktop-environment && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# [Optional] Build Tools for Python packages
# ----------------------------------------
# Most distributions work out of the box. If you encounter issues:
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends python3-dev build-essential && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# [Optional] VS Code Extensions
# ----------------------------------------
# Gemini Code Assist + Google Cloud Code
# https://marketplace.visualstudio.com/items?itemName=GoogleCloudTools.cloudcode
# RUN /opt/vscode/code code tunnel --accept-server-license-terms && \
#     /opt/vscode/code --install-extension googlecloudtools.cloudcode

# ----------------------------------------
# [Optional] Install pipx (takes a while)
# ----------------------------------------
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends pipx && \
#     pipx ensurepath && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Agent installations handled at runtime:
# - Claude Code: /etc/workstation-startup.d/300_workstation-customization.sh
# - Goose: /etc/workstation-startup.d/300_workstation-customization.sh
# - uv: /etc/workstation-startup.d/300_workstation-customization.sh
# - Gemini CLI: Should be included in base image
# ----------------------------------------

# ----------------------------------------
# Configure User Adding Overrides for Default Auth Behavior
# ----------------------------------------
RUN rm -f /etc/profile.d/disable_gcloud_gce_check.sh

# ----------------------------------------
# Runtime customization scripts
# ----------------------------------------
COPY ./assets/etc/workstation-startup.d/ /etc/workstation-startup.d/
RUN chmod +x /etc/workstation-startup.d/*
