#!/bin/sh

VERSION_NUMBER=$1
ARTIFACT_FOLDER = "artifact/monica$VERSION_NUMBER" 
DEPLOY_FOLDER = "deployartefact"
rm -rf $DEPLOY_FOLDER
rm -rf $artifact
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
tar -cvpzf ../deployartefact/monica$VERSION_NUMBER.tar.gz monica$VERSION_NUMBER --overwrite                   
cd ..