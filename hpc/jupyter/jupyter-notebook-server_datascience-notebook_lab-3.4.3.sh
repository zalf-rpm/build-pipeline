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

MOUNT_EXTENSION=~/jupyter/extensions
mkdir -p $MOUNT_EXTENSION
EXTENSION=/opt/conda/share/jupyter/lab/extensions

MOUNT_SETTINGS=~/jupyter/settings
mkdir -p $MOUNT_SETTINGS
SETTINGS=/opt/conda/share/jupyter/lab/settings

MOUNT_STAGING=~/jupyter/staging
mkdir -p $MOUNT_STAGING
STAGING=/opt/conda/share/jupyter/lab/staging

cd ${HOMEDIR}
export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITYENV_PREPEND_PATH="/opt/conda/bin"
singularity run --cleanenv \
-B $MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA,$MOUNT_JOVYAN:$JOVYAN,$MOUNT_EXTENSION:$EXTENSION,$MOUNT_SETTINGS:$SETTINGS,$MOUNT_STAGING:$STAGING \
$SINGULARITY_IMAGE 
printf 'jupyter exited' 1>&2