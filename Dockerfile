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

FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base:latest

# ----------------------------------------
# VS Code Server
# ----------------------------------------
RUN arch=$(uname -m) && \
if [ "${arch}" = "x86_64" ]; then \
arch="x64"; \
elif [ "${arch}" = "aarch64" ]; then \
arch="arm64"; \
elif [ "${arch}" = "armv7l" ]; then \
arch="armhf"; \
fi && \
mkdir -p /vscode-server && \
curl -o /vscode-server/vscode.tar.gz -L "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64"
RUN tar -xzf /vscode-server/vscode.tar.gz -C /vscode-server/
RUN rm /vscode-server/vscode.tar.gz

# Terraform to manage various kinds of infrastructure
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
RUN sudo apt update && sudo apt install -y zsh gnupg software-properties-common terraform
RUN apt-get clean

# Install zsh
ENV ZSH=/opt/workstation/oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
  git clone https://github.com/zsh-users/zsh-autosuggestions /opt/workstation/oh-my-zsh/plugins/zsh-autosuggestions && \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /opt/workstation/oh-my-zsh/custom/themes/powerlevel10k

# Install k9s
RUN curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
| grep "browser_download_url.*Linux_amd64.tar.gz" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi - && mkdir -p /opt/workstation/bin && tar -xf k9s_Linux_amd64.tar.gz -C /opt/workstation/bin

# Install extensions
# RUN wget -O terraform.vsix $(curl -q https://open-vsx.org/api/hashicorp/terraform/linux-x64 | jq -r '.files.download') \
#     && unzip terraform.vsix "extension/*" \
#     && mv extension /opt/code-oss/extensions/terraform

# RUN wget -O vscode-icons.vsix $(curl -q https://open-vsx.org/api/vscode-icons-team/vscode-icons | jq -r '.files.download') \
#     && unzip vscode-icons.vsix "extension/*" \
#     && mv extension /opt/code-oss/extensions/vscode-icons

# Copy workstation customization script
COPY /workstation-startup/300_workstation-customization.sh /etc/workstation-startup.d/300_workstation-customization.sh
RUN chmod +x /etc/workstation-startup.d/300_workstation-customization.sh

COPY /workstation-startup/110_start-vscode.sh /etc/workstation-startup.d/110_start-vscode.sh
RUN chmod +x /etc/workstation-startup.d/110_start-vscode.sh