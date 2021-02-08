#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_project? ?mount_climate? ?mount_output? ?batch_file? ?version? ?estimated_time? ?num_nodes? 
set -eu
[[ $# < 9 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_PROJECT=$4
MOUNT_DATA=$5
BATCH_LIST_FILE=$6
VERSION=$7
TIME=$8
NUM_NODES=${9}

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="hermes_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

#check if the singularity image exists 
SINGULARITY_IMAGE=hermes2go_${VERSION}.sif
IMAGE_DIR=~/singularity/hermes2go
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
cd $IMAGE_DIR
singularity pull docker://zalfrpm/hermes2go:${VERSION}
cd ~

fi

DATE=`date +%Y-%d-%B_%H%M%S`
HERMES_PROJECTDIR=/beegfs/rpm/projects/hermes2go/projects/${MOUNT_PROJECT}
HERMES_OUT=/beegfs/rpm/projects/hermes2go/out/${MOUNT_PROJECT}_${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $HERMES_OUT

HERMES_LOG=/beegfs/rpm/projects/hermes2go/log/${MOUNT_PROJECT}_${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $HERMES_LOG
BATCH_LIST_PATH=/hermes/project/${BATCH_LIST_FILE}

ARRAYSIZE=`singularity run -B ${HERMES_PROJECTDIR}:/hermes/project ${IMAGE_PATH} calcHermesBatch -size ${NUM_NODES} ${BATCH_LIST_PATH}`
ARRAYLIST=`singularity run -B ${HERMES_PROJECTDIR}:/hermes/project ${IMAGE_PATH} calcHermesBatch -list ${NUM_NODES} ${BATCH_LIST_PATH}`

#sbatch commands
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --array=0-${ARRAYSIZE} -o $HERMES_LOG/hermes-%j.out"

# sbatch script commands
HERMES_INPUT="${HERMES_PROJECTDIR} ${MOUNT_DATA} ${HERMES_OUT} ${IMAGE_PATH} ${BATCH_LIST_FILE} ${ARRAYLIST}"

sbatch $SBATCH_COMMANDS batch/sbatch_hermes.sh $HERMES_INPUT 
