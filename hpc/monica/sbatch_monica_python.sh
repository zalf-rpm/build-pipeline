#!/bin/bash -x
#SBATCH --partition=compute

SINGULARITY_IMAGE=$1
MOUNT_DATA=$2
MOUNT_DATA_PROJECT=$3
MONICA_OUT=$4
MOUNT_PARAMS=$5
WORKDIR=$6
SCRIPT=$7
shift 7
ADDITIONAL_PARAMETER=$@

DATA=/data
OUT=/out
PROJECT=/project
PARAMS=/monica-parameters

cd $WORKDIR
singularity run -B \
$MOUNT_DATA:$DATA,\
$MOUNT_DATA_PROJECT:$PROJECT,\
$MONICA_OUT:$OUT,\
$MOUNT_PARAMS:$PARAMS \
${SINGULARITY_IMAGE} python ${SCRIPT} ${ADDITIONAL_PARAMETER}
