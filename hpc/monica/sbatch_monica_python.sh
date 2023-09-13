#!/bin/bash -x

SINGULARITY_IMAGE=$1
MOUNT_DATA=$2
MOUNT_DATA_PROJECT=$3
MONICA_OUT=$4
MOUNT_PARAMS=$5
MOUNT_MAS_INFRASTRUCTURE=$6
WORKDIR=$7
SCRIPT=$8
shift 8
ADDITIONAL_PARAMETER=$@

DATA=/data
OUT=/out
PROJECT=/project
PARAMS=/monica-parameters
MAS_INFRASTRUCTURE=/mas-infrastructure

cd $WORKDIR
echo "set singularity home"
SINGULARITY_HOME=${WORKDIR}
export SINGULARITY_HOME

echo "start python script"

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME -B \
$MOUNT_DATA:$DATA:ro,\
$MOUNT_DATA_PROJECT:$PROJECT:ro,\
$MONICA_OUT:$OUT,\
$MOUNT_PARAMS:$PARAMS:ro,\
$MOUNT_MAS_INFRASTRUCTURE:$MAS_INFRASTRUCTURE:ro \
${SINGULARITY_IMAGE} python ${SCRIPT} ${ADDITIONAL_PARAMETER}
