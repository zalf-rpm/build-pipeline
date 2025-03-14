#!/usr/bin/env bash
set -e

echo "Install RootPainter"
dpkg --add-architecture i386
dpkg -i /headless/install/RootPainter_0.2.27_Ubuntu22.deb