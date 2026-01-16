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
# Install System Dependencies and XFCE
# ----------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    xfce4 \
    xfce4-goodies \
    xbase-clients \
    dbus-x11 \
    psmisc \
    python3-psutil \
    xserver-xorg-video-dummy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Install Google Chrome and Chrome Remote Desktop
# ----------------------------------------
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list > /dev/null && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] https://dl.google.com/linux/chrome-remote-desktop/deb stable main" | tee /etc/apt/sources.list.d/chrome-remote-desktop.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable chrome-remote-desktop && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Chrome
# ----------------------------------------
# Chrome Sandbox Fix
# Chrome will crash in Docker without --no-sandbox. 
# We divert the binary to force this flag.
RUN dpkg-divert --add --rename --divert /usr/bin/google-chrome-stable.real /usr/bin/google-chrome-stable && \
    echo '#!/bin/bash' > /usr/bin/google-chrome-stable && \
    echo 'exec /usr/bin/google-chrome-stable.real --no-sandbox --disable-dev-shm-usage "$@"' >> /usr/bin/google-chrome-stable && \
    chmod +x /usr/bin/google-chrome-stable

# ----------------------------------------
# Mock systemctl
# ----------------------------------------
RUN echo '#!/bin/bash' > /usr/bin/systemctl \
    && echo 'echo "Mock systemctl: $@"' >> /usr/bin/systemctl \
    && echo 'exit 0' >> /usr/bin/systemctl \
    && chmod +x /usr/bin/systemctl

# ----------------------------------------
# Install Antigravity
# ----------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null && \
    apt-get update && \
    apt-get install -y antigravity && \
    dpkg-divert --add --rename --divert /usr/bin/antigravity.real /usr/bin/antigravity && \
    echo '#!/bin/bash' > /usr/bin/antigravity && \
    echo 'exec /usr/bin/antigravity.real --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"' >> /usr/bin/antigravity && \    
    chmod +x /usr/bin/antigravity

# ----------------------------------------
# Terraform to manage various kinds of infrastructure
# ----------------------------------------
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends zsh gnupg software-properties-common terraform && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Install Oh My Zsh with plugins and theme
# ----------------------------------------
ENV ZSH=/opt/workstation/oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /opt/workstation/oh-my-zsh/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/workstation/oh-my-zsh/custom/themes/powerlevel10k

# ----------------------------------------
# [Optional] Install k9s
# ----------------------------------------
# RUN curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
# | grep "browser_download_url.*Linux_amd64.tar.gz" \
# | cut -d : -f 2,3 \
# | tr -d \" \
# | wget -qi - && mkdir -p /opt/workstation/bin && tar -xf k9s_Linux_amd64.tar.gz -C /opt/workstation/bin

# ----------------------------------------
# [Optional] Setup GUI
# ----------------------------------------
# RUN apt-get update && \
#     apt-get upgrade -y && \
#     apt-get install -y --no-install-recommends \
#     mate-desktop-environment && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Python venv
# ----------------------------------------
# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Dynamically detect Python version and install the matching venv package
RUN apt-get update && \
    export PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")') && \
    apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION}-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Build Tools
# ----------------------------------------
# Most distributions work out of the box. If you encounter issues:
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     python3-dev build-essential && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Install extensions
# ----------------------------------------

# Gemini Code Assist + Google Cloud Code
# https://marketplace.visualstudio.com/items?itemName=GoogleCloudTools.cloudcode
# RUN /opt/vscode/code code tunnel --accept-server-license-terms
# RUN /opt/vscode/code --install-extension googlecloudtools.cloudcode

# ----------------------------------------
# Install Claude Code
# ----------------------------------------
# Handled in /etc/workstation-startup.d/300_workstation-customization.sh

# ----------------------------------------
# Additional CLI Dependencies
# ----------------------------------------
# bzip2 for Goose, inotify-tools for file watching
# Note: curl/ca-certificates should already be in base image
RUN apt-get update && \
    apt-get install -y --no-install-recommends bzip2 inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Install Gemini CLI
# ----------------------------------------
# Should be included in base image

# ----------------------------------------
# [Optional] Install pipx (takes a while)
# ----------------------------------------
# RUN apt-get update && apt-get install -y --no-install-recommends pipx && \
#     pipx ensurepath && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*

# ----------------------------------------
# Agent installations handled at runtime:
# - Claude Code: /etc/workstation-startup.d/300_workstation-customization.sh
# - Goose: /etc/workstation-startup.d/300_workstation-customization.sh
# - uv: /etc/workstation-startup.d/300_workstation-customization.sh
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
