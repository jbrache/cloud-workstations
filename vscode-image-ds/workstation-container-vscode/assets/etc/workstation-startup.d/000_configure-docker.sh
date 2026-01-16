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
# Startup script to configure docker inside workstation container.
#

# https://github.com/docker/cli/issues/4807 - The current default for hard and
# soft limits on file descriptors are both set to 1048576. Docker 25.0.0
# attempts to lower the hard limit to a value lower than the soft limit, which
# causes the service to fail to laod. For the time being we just leaving the
# defaults as that is what the previous version of Docker (essentailly) did.
sed -i 's/ulimit -Hn 524288/# ulimit -Hn 524288/g' /etc/init.d/docker;
sudo --preserve-env=DOCKER_OPTS /google/scripts/wrapdocker/wrapdocker &
