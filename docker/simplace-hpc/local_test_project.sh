#!/bin/bash
MOUNT_DATA=${1}/simplace_data
MOUNT_WORK=${1}/simplacecheckout_run/trunk/simulation/
MOUNT_OUT=${1}/simplace_out
MOUNT_PROJECT=${1}/simplace_project
SOLUTION=SimulationExperimentTemplate/solution/Lintul5.sol.xml
PROJECT=SimulationExperimentTemplate/project/Lintul5All.proj.xml
DEBUG=true
LINE_START=1
LINE_END=8
TESTRUN=false

VERSION=4.3_final.1

CONTAINER_NAME="simplace_test_run"

docker run \
--mount type=bind,source=$MOUNT_WORK,target=/simplace/SIMPLACE_WORK \
--mount type=bind,source=$MOUNT_OUT,target=/outputs \
--mount type=bind,source=$MOUNT_DATA,target=/data \
--mount type=bind,source=$MOUNT_PROJECT,target=/projects \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace-hpc:$VERSION $SOLUTION $PROJECT $DEBUG $LINE_START $LINE_END $TESTRUN
