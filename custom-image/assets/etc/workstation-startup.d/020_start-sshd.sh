#!/bin/bash
#
# Copyright 2022 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Startup script to start OpenSSH Daemon.
#

echo "Generating host SSH keys"
yes | ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -t rsa -C 'host' -N '' > /dev/null
yes | ssh-keygen -q -f /etc/ssh/ssh_host_ecdsa_key -t ecdsa -C 'host' -N '' > /dev/null
yes | ssh-keygen -q -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -C 'host' -N '' > /dev/null

echo "Starting sshd"
mkdir /run/sshd
/usr/sbin/sshd
