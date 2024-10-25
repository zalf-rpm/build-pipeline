#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_project? ?mount_climate? ?mount_output? ?batch_file? ?version? ?estimated_time? ?num_nodes? 
set -eu
[[ $# < 8 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_EXEC_ID=$2
HERMES_PROJECTDIR=$3
MOUNT_CLIMATE_DATA=$4
BATCH_LIST_FILE=$5
VERSION=$6
TIME=$7
NUM_NODES=$8

#sbatch job name 
SBATCH_JOB_NAME="hermes_${USER}_${JOB_EXEC_ID}"

#check if the project directory exists
if [ ! -d $HERMES_PROJECTDIR ]; then
  echo "Project directory does not exist"
  exit 1
fi


#check if the singularity image exists 
SINGULARITY_IMAGE=hermes2go_${VERSION}.sif
IMAGE_DIR=~/singularity/hermes2go
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

# always download the latest image, remove old latest image
if [[ $VERSION == "latest" && -e ${IMAGE_PATH} ]] ; then
  # remove old image
  rm -f ${IMAGE_PATH}
fi 

# download the image if it does not exist
mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_PATH} ] ; then
echo "Download version: ${VERSION}"
cd $IMAGE_DIR
singularity pull --name hermes2go_${VERSION}.sif docker://zalfrpm/hermes2go:${VERSION}
cd ~
fi

# create output and log directories
DATE=`date +%Y-%d-%B_%H%M%S`
HERMES_OUT=$HERMES_PROJECTDIR/out/out_${DATE}
mkdir -p $HERMES_OUT

HERMES_LOG=$HERMES_PROJECTDIR/log/log_${DATE}
mkdir -p $HERMES_LOG

HERMES_WEATHER=$HERMES_PROJECTDIR/weather
mkdir -p $HERMES_WEATHER

# create batch list path... batch file should be in the project directory
BATCH_LIST_PATH=$HERMES_PROJECTDIR/${BATCH_LIST_FILE}

# analyze the batch file, get the array size and array list, to distribute the jobs to the nodes
ARRAYSIZE=`singularity run -B ${HERMES_PROJECTDIR}:$HERMES_PROJECTDIR ${IMAGE_PATH} calcHermesBatch -size ${NUM_NODES} -batch ${BATCH_LIST_PATH}`
ARRAYLIST=`singularity run -B ${HERMES_PROJECTDIR}:$HERMES_PROJECTDIR ${IMAGE_PATH} calcHermesBatch -list ${NUM_NODES} -batch ${BATCH_LIST_PATH}`

#sbatch command for array jobs
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --array=0-${ARRAYSIZE} -o $HERMES_LOG/hermes-%j.out"

# add hermes input to the sbatch command
HERMES_INPUT="${HERMES_PROJECTDIR} ${MOUNT_CLIMATE_DATA} ${HERMES_OUT} ${IMAGE_PATH} ${BATCH_LIST_FILE} ${ARRAYLIST}"

sbatch $SBATCH_COMMANDS /beegfs/common/batch/sbatch_hermes.sh $HERMES_INPUT 
