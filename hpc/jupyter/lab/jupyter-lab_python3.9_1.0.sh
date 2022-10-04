#!/bin/bash -x
#SBATCH --time=00:015:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40

USER=$1
LOGIN_HOST=$2
MOUNT_PROJECT=$3
MOUNT_DATA=$4
MOUNT_HOME=$5
PLAYGROUND=$6
JWORK=$7
IMAGE_PATH=$8


PROJECT=${JWORK}/project
DATA=${JWORK}/data
USERHOME=${JWORK}/home

cd ${PLAYGROUND}
cp /beegfs/common/batch/startjupyter.sh .
STATUS=$?
if [ $STATUS != 0 ]; then                   
   echo "Copy startjupyter.sh: $STATUS - failed" 
   exit 1
fi

export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITY_HOME=$PLAYGROUND

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
-B ${SINGULARITY_HOME}:${SINGULARITY_HOME},$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_HOME:$USERHOME \
$IMAGE_PATH /bin/bash startjupyter.sh $PLAYGROUND

printf 'jupyter exited' 1>&2