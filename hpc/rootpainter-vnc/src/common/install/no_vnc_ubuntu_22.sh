#!/usr/bin/env bash
### every exit != 0 fails the script
set -e
set -u

echo "Install noVNC - HTML5 based VNC viewer"
apt-get -y install novnc python3-websockify python3-numpy
apt-get clean -y