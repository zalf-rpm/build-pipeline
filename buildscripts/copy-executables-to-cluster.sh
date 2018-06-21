#!/bin/sh
# required parameter - cluster number (1,2,3)


cd ../../monica/_cmake_linux

mkdir -p ../../cluster$1-release/monica/

cp -af monica ../../cluster$1-release/monica/

cp -af monica-run ../../cluster$1-release/monica/

cp -af monica-zmq-control-send ../../cluster$1-release/monica/

cp -af monica-zmq-run ../../cluster$1-release/monica/

cp -af monica_python.so ../../cluster$1-release/monica/

cp -af monica-zmq-control ../../cluster$1-release/monica/

cp -af monica-zmq-proxy ../../cluster$1-release/monica/

cp -af monica-zmq-server ../../cluster$1-release/monica/
