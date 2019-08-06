#!/bin/sh

if [ -z "$1" ]; then
	INSTALL_PATH="../../"
else 
	INSTALL_PATH=$1
fi

cd $INSTALL_PATH

if [ -d "./vcpkg" ]; then
  # check if vcpkg exists and is a valid git clone
  cd vcpkg
  ISGITREPRO=$(git rev-parse --is-inside-work-tree)
  cd ..
  if [ ! $ISGITREPRO ]; then
	  rm -r -f vcpkg
      echo "deleted invalid git folder"
  else
      echo "vcpkg exists"
  fi
fi

# download from git and install vcpkg
if [ ! -d "./vcpkg" ]; then
    echo "vcpkg does not exist"
    # create vcpkg if it does not exist
    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh 
    cd ..
fi

cd vcpkg
# add packages to install here
# zeromq
./vcpkg install zeromq:x64-linux
./vcpkg install capnproto:x64-linux

rm -rf buildtrees
