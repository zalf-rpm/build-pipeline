#!/bin/sh -x
#SBATCH --time=00:015:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --output=/home/%u/jupyter-server.job.%j


SCRIPT_USER=$1
LOGIN_HOST_NAME=$2
MOUNT_PROJECT=$3
MOUNT_DATA=$4
HOMEDIR=$5
SINGULARITY_IMAGE=$6

PROJECT=${HOMEDIR}/project
DATA=${HOMEDIR}/data
JOVYAN=/home/jovyan

MOUNT_JOVYAN=~/jovyan/work
mkdir -p $MOUNT_JOVYAN

cd ${HOMEDIR}
export SINGULARITYENV_USE_HTTPS=yes

singularity run \
-B $MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA,$MOUNT_JOVYAN:$JOVYAN \
$SINGULARITY_IMAGE 
printf 'jupyter exited' 1>&2