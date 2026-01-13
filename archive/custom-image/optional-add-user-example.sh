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

# Adjusted Dockerfile - Instead of using profile.d to init on login, it watches /etc/passwd to 
# see when new users are added and inits them when they are created.

# It adds a new apt package dependency to allow the file system watching
# but otherwise consolidates everything into the startup scripts, so the 
# logic isn't spread out across multiple files.

export groups=docker,sudo,users

# ----------------------------------------
# Bash example
# ----------------------------------------
sudo useradd -m josebash -G $groups --shell /bin/bash > /dev/null
# sudo passwd -d jose >/dev/null

# sudo su jose - # wrong
# The dash should go before the username, otherwise it doesn't
# load the user profile which is why the profile.d script didn't get executed

sudo su - josebash # right (dash before username)

# ----------------------------------------
# Zsh Example
# ----------------------------------------
sudo useradd -m josezsh -G $groups --shell /usr/bin/zsh > /dev/null
sudo su - josezsh