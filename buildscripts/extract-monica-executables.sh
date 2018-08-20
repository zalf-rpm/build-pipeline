#!/bin/bash
MONICA_EXECUTABLES="monica-executables"
cd artifact/deployartefact
rm -rf ../../$MONICA_EXECUTABLES
mkdir -p ../../$MONICA_EXECUTABLES
for file in monica_*.tar.gz; do
    echo "extracting $file"
    tar -vxzf $file -C ../../$MONICA_EXECUTABLES/ --overwrite  
done
