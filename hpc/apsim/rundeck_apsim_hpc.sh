#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?command_line? ?mount_storage? ?estimated_time? ?used_cpu? 
set -eu
[[ $# < 7 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_STORAGE=$4
TIME=$5
CPU=$6

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="apsim_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

#check if the singularity image exists 
SINGULARITY_IMAGE=apsim-classic_79.1.sif
IMAGE_DIR=~/singularity/apsim
if [ ! -e ${IMAGE_DIR}/${SINGULARITY_IMAGE} ] ; then
echo "File '${IMAGE_DIR}/${SINGULARITY_IMAGE}' not found"
exit 1
fi

cd ~

#sbatch commands
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --cpus-per-task=${CPU} -o log/apsim-%j"

#apsim sbatch script commands
shift 6
APSIM_INPUT="${MOUNT_STORAGE} ${IMAGE_DIR}/${SINGULARITY_IMAGE} ${SBATCH_JOB_NAME} $@"

echo "sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh $APSIM_INPUT"
sbatch $SBATCH_COMMANDS batch/sbatch_apsim.sh $APSIM_INPUT 
