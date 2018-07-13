#!/bin/sh

VERSION_NUMBER=$1
MONICA_NAME="monica_$VERSION_NUMBER" 
ARTIFACT_ROOT="artifact"
ARTIFACT_FOLDER="$ARTIFACT_ROOT/$MONICA_NAME" 
DEPLOY_FOLDER="deployartefact"
rm -rf $DEPLOY_FOLDER
rm -rf $ARTIFACT_ROOT
mkdir -p $ARTIFACT_FOLDER
mkdir -p $DEPLOY_FOLDER
cd monica/_cmake_linux

cp -af monica ../../$ARTIFACT_FOLDER           
cp -af monica-run ../../$ARTIFACT_FOLDER
cp -af monica-zmq-control-send ../../$ARTIFACT_FOLDER
cp -af monica-zmq-run ../../$ARTIFACT_FOLDER
cp -af monica_python.so ../../$ARTIFACT_FOLDER
cp -af monica-zmq-control ../../$ARTIFACT_FOLDER
cp -af monica-zmq-proxy ../../$ARTIFACT_FOLDER
cp -af monica-zmq-server ../../$ARTIFACT_FOLDER

cd ../../artifact
tar -cvpzf ../deployartefact/$MONICA_NAME.tar.gz $MONICA_NAME --overwrite                   
cd ..
