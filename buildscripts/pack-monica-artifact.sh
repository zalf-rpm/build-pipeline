VersionNumber=$1
ArtifactFolder = "artifact/monica$VersionNumber" 
DeployFolder = "deployartefact"
rm -rf $DeployFolder
rm -rf $artifact
mkdir -p $ArtifactFolder
mkdir -p $DeployFolder
cd monica/_cmake_linux

cp -af monica ../../$ArtifactFolder           
cp -af monica-run ../../$ArtifactFolder
cp -af monica-zmq-control-send ../../$ArtifactFolder
cp -af monica-zmq-run ../../$ArtifactFolder
cp -af monica_python.so ../../$ArtifactFolder
cp -af monica-zmq-control ../../$ArtifactFolder
cp -af monica-zmq-proxy ../../$ArtifactFolder
cp -af monica-zmq-server ../../$ArtifactFolder

cd ../../artifact
tar -cvpzf ../deployartefact/monica$fullVersionStr.tar.gz monica$fullVersionStr --overwrite                   
cd ..