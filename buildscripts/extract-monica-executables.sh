#!/bin/bash
# paramenter: <source path> <extraction path>  
MONICA_EXECUTABLES=$2
ARTIFACT_PATH=$1
cd $ARTIFACT_PATH
rm -rf ../../$MONICA_EXECUTABLES
mkdir -p ../../$MONICA_EXECUTABLES
for file in monica_*.tar.gz; do
    echo "extracting $file"
    tar -vxzf $file -C ../../$MONICA_EXECUTABLES/ --overwrite  
done
