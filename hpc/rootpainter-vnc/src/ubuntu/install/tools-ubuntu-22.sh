#!/usr/bin/env bash
### every exit != 0 fails the script
set -e

echo "Install some common tools for further installation"
apt-get update 
apt-get install -y vim wget net-tools locales bzip2
apt-get install -y qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools
apt-get clean -y

echo "generate locales for en_US.UTF-8"
locale-gen en_US.UTF-8