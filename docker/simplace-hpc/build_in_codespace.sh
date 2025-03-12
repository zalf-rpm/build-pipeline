
#!/bin/bash +x

# requirements:
# docker 
# precompiled version of simplace
# version number of simplace_run

# copy first the compiled /lapclient/console into SOURCEDIR

SIMPLACE_SVN_VERSION=${1:-"5.1-0"} # default version number + revision number
SOURCEDIR=${2:-./simplace/console} # default source directory
WORKDIR=$(pwd)

# remove windows executable
cd $SOURCEDIR
echo $(pwd)
ls -al
rm simplace.exe

cd $WORKDIR
# build docker image
docker build -t zalfrpm/simplace-hpc:$SIMPLACE_SVN_VERSION --no-cache --build-arg EXECUTABLE_SOURCE=$SOURCEDIR .

