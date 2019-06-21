#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_project? ?mount_climate? ?mount_output? ?batch_file? ?version? ?estimated_time? ?num_nodes? 
set -eu
[[ $# < 10 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_PROJECT=$4
MOUNT_DATA=$5
MOUNT_OUTPUT=$6
BATCH_LIST_FILE=$7
VERSION=$8
TIME=$9
NUM_NODES=${10}


# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="hermes_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

#check if the singularity image exists 
SINGULARITY_IMAGE=hermes-to-go_${VERSION}.sif
IMAGE_DIR=~/singularity/hermes
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
cd $IMAGE_DIR
singularity pull docker://zalfrpm/hermes-to-go:${VERSION}
cd ~

fi


ARRAYSIZE=`singularity run -B ${MOUNT_PROJECT}:/hermes/project ${IMAGE_PATH} calcHermesBatch -size ${NUM_NODES} ${BATCH_LIST_FILE}`
ARRAYLIST=`singularity run -B ${MOUNT_PROJECT}:/hermes/project ${IMAGE_PATH} calcHermesBatch -list ${NUM_NODES} ${BATCH_LIST_FILE}`

#sbatch commands
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --array=0-${ARRAYSIZE} -o log/hermes-%j.out"

# sbatch script commands
HERMES_INPUT="${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_OUTPUT} ${IMAGE_PATH} ${BATCH_LIST_FILE} ${ARRAYLIST}"

echo "sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh $HERMES_INPUT"
#sbatch $SBATCH_COMMANDS batch/sbatch_hermes.sh $HERMES_INPUT 
