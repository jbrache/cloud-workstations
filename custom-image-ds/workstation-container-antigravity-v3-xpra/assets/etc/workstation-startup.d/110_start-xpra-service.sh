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

echo "Starting Xpra for GUI..."

# https://medium.com/@roken/extending-google-cloud-workstations-containers-to-run-any-gui-based-program-133d0f905106
# [ Option 1 ] - xterm
# runuser user -c -l "xpra start --bind-tcp=0.0.0.0:80 --min-port=80 --html=on --systemd-run=yes --daemon=no --dbus-launch='' --dbus-control=no --start-child-after-connect=xterm"

# [ Option 2 ] - Gnome
# runuser user -c -l "xpra start-desktop :7 --bind-tcp=0.0.0.0:80 --min-port=80 --html=on --systemd-run=yes --daemon=no --dbus-launch='' --dbus-control=no --start-child=gnome-session"

# [ Option 3 ] MATE Desktop
runuser user -c -l "xpra start-desktop :7 --bind-tcp=0.0.0.0:80 --min-port=80 --html=on --systemd-run=yes --daemon=no --dbus-launch='' --dbus-control=no --start-child=mate-session"
