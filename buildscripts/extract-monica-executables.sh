#!/bin/bash
MONICA_EXECUTABLES = "monica-executables"
cd ../../artifact
rm -rf $MONICA_EXECUTABLES
mkdir $MONICA_EXECUTABLES
larray=($(ls))
for i in larray; do
    if [[$i == monica*.tar.gz]]
    {
        echo "extracting $i"
        tar -vxzf $i ../$MONICA_EXECUTABLES/ --overwrite  
    }
done
