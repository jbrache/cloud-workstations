# syntax=docker/dockerfile:1

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


#######################################################
# Xpra Container
#######################################################

FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

# Use ARG to avoid apt-get warnings
ARG DEBIAN_FRONTEND=noninteractive

# Install Xpra
RUN curl http://xpra.org/gpg.asc > /etc/apt/keyrings/xpra.asc && \
echo "deb [signed-by=/etc/apt/keyrings/xpra.asc] http://xpra.org/ noble main" > \
  /etc/apt/sources.list.d/xpra.list && \
  apt-get update && apt-get install -y \
  xpra \
  xpra-x11 \
  xpra-html5 \
  python3-requests \
  python3-paramiko \
  python3-zeroconf \
  python3-avahi && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Install GNOME
# RUN apt-get update && apt-get install -y \
#     gnome-software \
#     gnome-software-common \
#     gnome-software-plugin-snap \
#     libappstream-glib8 \
#     libgd3 \
#     colord \
#     gnome-control-center \
#     gvfs-backends \
#     hplip \
#     libgphoto2-6 \
#     libsane1 \
#     sane-utils \
#     ubuntu-desktop-minimal && \
#   apt-get remove -y gnome-initial-setup && \
#   apt-get remove -y --purge cloud-init && \
#   apt-get clean && \
#   rm -rf /var/lib/apt/lists/* && \
#   chmod -x /usr/lib/ubuntu-release-upgrader/check-new-release-gtk

# Install Antigravity
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null && \
    apt-get update && \
    apt-get install -y antigravity

# Install Google Chrome
# RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
#     echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list > /dev/null && \
#     apt-get update && \
#     apt-get install -y google-chrome-stable

# Divert the original Chrome executable to a new location and create a wrapper script.
# This ensures the fix persists even when the Chrome package is updated.
# RUN dpkg-divert --add --rename --divert /usr/bin/google-chrome-stable.real /usr/bin/google-chrome-stable && \
#     echo '#!/bin/bash' > /usr/bin/google-chrome-stable && \
#     echo 'exec /usr/bin/google-chrome-stable.real --no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage "$@"' >> /usr/bin/google-chrome-stable && \
#     chmod +x /usr/bin/google-chrome-stable

# Install google-chrome
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
  apt-get update && \
  apt install -y ./google-chrome*.deb && \
  rm google-chrome*.deb && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  # Ensure chrome will work in a headless environment without gpu support by
  # specifying environment variables and flags
  echo "QT_X11_NO_MITSHM=1 _X11_NO_MITSHM=1 _MITSHM=0 $(tail -n -1 /opt/google/chrome/google-chrome) --disable-gpu --disable-dev-shm-usage --use-gl=swiftshader" >> /opt/google/chrome/google-chrome && \
  sed -i 'N;$!P;D' /opt/google/chrome/google-chrome

# ----------------------------------------
# Runtime customization scripts
# ----------------------------------------
COPY ./assets/etc/workstation-startup.d/. /etc/workstation-startup.d/
RUN chmod +x /etc/workstation-startup.d/*