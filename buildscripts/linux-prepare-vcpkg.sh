#!/bin/sh
cd ../../
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh 
./vcpkg install zeromq:x64-linux

cd ..
