#!/bin/bash -x

PYTHON=/home/rpm/.conda/envs/py39_4/bin/python

WORKDIR=$1
SCRIPT=$2
OUT=$3
shift 3
ADDITIONAL_PARAMETERS=$@

cd $WORKDIR

$PYTHON $SCRIPT path_to_out=$OUT/ ${ADDITIONAL_PARAMETERS}
