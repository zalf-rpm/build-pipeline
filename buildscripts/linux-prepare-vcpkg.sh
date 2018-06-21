#!/bin/sh
cd ../../

if [ -d vcpkg ]; then
  # check if vcpkg exists and is a valid git clone
  cd vcpkg
  if [! git rev-parse --is-inside-work-tree]; then
      cd ..
......rm -r -f vcpkg
  fi
fi

if [ ! -d vcpkg ]; then
    # if v
    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh 
    ./vcpkg install zeromq:x64-linux
    cd ..
fi
