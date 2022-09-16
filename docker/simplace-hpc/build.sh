
#!/bin/bash +x

# requirements:
# docker 
# subversion
# precompiled version of simplace

PWD=$(pwd)
WORKDIR=${1:-$PWD}
SOURCEDIR=${2:-$HOME/simplace}

# copy compiled simplace folder into build folder
SIMPLACEEXE=$WORKDIR/simplace_exe
rm -rf $SIMPLACEEXE
cp -r $SOURCEDIR/lapclient/console $SIMPLACEEXE
# remove windows executable
cd $SIMPLACEEXE
echo $(pwd)
ls
rm simplace.exe

# get simplace_run svn revision
cd $SOURCEDIR/simplace_run

SIMPLACR_RUN_VERSION=$(svnversion)
echo "version:" $SIMPLACR_RUN_VERSION

cd $WORKDIR
# build docker image
docker build -t zalfrpm/simplace-hpc:5.0-$SIMPLACR_RUN_VERSION --no-cache --build-arg EXECUTABLE_SOURCE=simplace_exe .

