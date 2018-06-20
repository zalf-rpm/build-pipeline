#!/bin/sh
cd ../../
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh 
./vcpkg install zeromq:x64-linux

cd ..

git clone https://github.com/zalf-rpm/monica.git
git clone https://github.com/zalf-rpm/sys-libs.git
git clone https://github.com/zalf-rpm/util.git
git clone https://github.com/zalf-rpm/monica-parameters.git


cd monica
mkdir _cmake_linux
cd  _cmake_linux
cmake .. -DCMAKE_TOOLCHAIN_FILE=../../vcpkg/scripts/buildsystems/vcpkg.cmake -DCMAKE_BUILD_TYPE=Release
make -j 20