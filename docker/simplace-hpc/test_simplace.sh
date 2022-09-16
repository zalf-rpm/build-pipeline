#!/bin/bash -x

# requirements:
# docker
# /simplace/SIMPLACE_WORK must contain the SimulationExperimentTemplate simulation 
# from /simplace_run/simulation

PWD=$(pwd)
rootDir=${1:-$PWD}
IMG=${2:-'zalfrpm/simplace-hpc:5.0'}

TEST_PATH_WORK=$rootDir/simplace/SIMPLACE_WORK
TEST_PATH_OUT=$rootDir/simplace/out
TEST_PATH_DATA=$rootDir/simplace/data
TEST_PATH_PROJECTS=$rootDir/simplace/projects

mkdir -p $TEST_PATH_OUT
mkdir -p $TEST_PATH_DATA
mkdir -p $TEST_PATH_PROJECTS

SIMPLACE_WORKDIR=/simplace/SIMPLACE_WORK
OUTDIR=/outputs
DATADIR=/data
PROJECTDIR=/projects

touch ${TEST_PATH_OUT}/myoutput.txt
touch ${TEST_PATH_DATA}/mydata.txt
touch ${TEST_PATH_PROJECTS}/myproject.txt

SOLUTION=SimulationExperimentTemplate/solution/Lintul5.sol.xml
PROJECT=SimulationExperimentTemplate/project/Lintul5All.proj.xml

docker run --rm \
--mount type=bind,source=${TEST_PATH_WORK},target=${SIMPLACE_WORKDIR} \
--mount type=bind,source=${TEST_PATH_OUT},target=${OUTDIR} \
--mount type=bind,source=${TEST_PATH_DATA},target=${DATADIR} \
--mount type=bind,source=${TEST_PATH_PROJECTS},target=${PROJECTDIR} \
--user $(id -u):$(id -g) \
$IMG /simplace_start.sh $SOLUTION $PROJECT true 1 8 false