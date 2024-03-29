#!/bin/bash
#/ usage: start ?user? ?job_name? ?job_exec_id? ?solution_path? ?project_path? ?version? ?lines? ?debug? ?estimated_time? ?used_cpu? ?mount_data? ?mount_work? ?mount_out? ?mount_out_zip? ?mount_project? ?use_high_memory?
set -eu
[[ $# != 15 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3

SOLUTION_PATH=$4
PROJECT_PATH=$5
VERSION=$6
LINE_SPLITUPSTR=$7
DEBUG=$8
TIME=${9}
MOUNT_DATA=${10}
MOUNT_WORK=${11}
MOUNT_OUT=${12}
MOUNT_OUT_ZIP=${13}
MOUNT_PROJECT=${14}
USEHIGHMEM=${15}

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

HPC_PARTITION="--partition=compute"
if [ $USEHIGHMEM == "true" ] ; then 
  HPC_PARTITION="--partition=highmem"
fi

#sbatch job name 
SBATCH_JOB_NAME="simpl_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

DATE=`date +%Y-%d-%B_%H%M%S`
MOUNT_OUT_ZIP=$MOUNT_OUT_ZIP/${SBATCH_JOB_NAME}_$DATE
mkdir $MOUNT_OUT_ZIP

#check if the singularity image exists 
SINGULARITY_IMAGE=simplace_${VERSION}.sif
IMAGE_DIR=~/singularity/simplace
if [ ! -e ${IMAGE_DIR}/${SINGULARITY_IMAGE} ] ; then
echo "File '${IMAGE_DIR}/${SINGULARITY_IMAGE}' not found"
exit 1
fi

cd ~
SIMPLACE_LOG=/beegfs/rpm/projects/simplace/log/${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $SIMPLACE_LOG

IFS=',' # (,) is set as delimiter
read -ra ADDR <<< "$LINE_SPLITUPSTR" # str is read into an array as tokens separated by IFS

for i in "${ADDR[@]}"; do # access each element of array
    IFS='-' # (-) is set as delimiter
    read -ra SOME <<< "$i" # string is read into an array as tokens separated by IFS
    IFS=' ' # reset to default value after usage
    STARTLINE=${SOME[0]}
    ENDLINE=${SOME[1]}
	#sbatch commands
	SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME}_${i} --time=${TIME} --cpus-per-task=40 ${HPC_PARTITION} -o $SIMPLACE_LOG/simplace-%j"
	#simplace sbatch script commands
    SIMPLACE_INPUT="${MOUNT_DATA} ${MOUNT_WORK} ${MOUNT_OUT} ${MOUNT_OUT_ZIP} ${SIMPLACE_LOG} ${MOUNT_PROJECT} ${SOLUTION_PATH} ${PROJECT_PATH} ${IMAGE_DIR}/${SINGULARITY_IMAGE} ${DEBUG} ${STARTLINE} ${ENDLINE} ${SBATCH_JOB_NAME}_${i} false"
    echo "First  $STARTLINE"
    echo "Second $ENDLINE"
    echo "$i"

	echo "sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh $SIMPLACE_INPUT"
	sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh $SIMPLACE_INPUT 
done
