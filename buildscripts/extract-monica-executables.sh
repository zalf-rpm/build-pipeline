#!/bin/sh
MONICA_NAME=$1
mkdir monica-executables
tar -vxzf $MONICA_NAME.tar.gz /monica-executables/ --overwrite  