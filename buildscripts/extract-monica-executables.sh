#!/bin/bash
# paramenter: <source path> <extraction path>  
MONICA_EXECUTABLES=$2
ARTIFACT_PATH=$1
rm -rf $MONICA_EXECUTABLES
mkdir -p $MONICA_EXECUTABLES
cd $ARTIFACT_PATH
for file in monica_*.tar.gz; do
    echo "extracting $file"
    tar -vxzf $file -C $MONICA_EXECUTABLES/ --overwrite  
done
