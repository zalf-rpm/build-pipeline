#!/bin/sh
cd ../../

if [ -d "./vcpkg" ]; then
  # check if vcpkg exists and is a valid git clone
  cd vcpkg
  ISGITREPRO=$(git rev-parse --is-inside-work-tree)
  cd ..
  if [ ! $ISGITREPRO ]; then
......rm -r -f vcpkg
      echo "deleted invalid git folder"
  else
      echo "vcpkg exists"
  fi
fi


if [ ! -d "./vcpkg" ]; then
    echo "vcpkg does not exist"
    # create vcpkg if it does not exist
    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh 
    ./vcpkg install zeromq:x64-linux
    cd ..
fi
