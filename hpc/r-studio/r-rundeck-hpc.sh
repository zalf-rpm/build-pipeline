#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?mount_climate_data? ?mount_project_data? ?estimated_time? 
set -eu
[[ $# < 6 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
LOGIN_HOST=$3
MOUNT_DATA=$4
MOUNT_PROJECT=$5
TIME=$6

#sbatch job name 
SBATCH_JOB_NAME="R_${USER}_${JOB_EXEC_ID}"

# get r-studio image from docker
IMAGE_DIR=~/singularity/R
SINGULARITY_IMAGE=rstudio.sif
IMAGE_RSTUDIO_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}
mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_RSTUDIO_PATH} ] ; then
echo "File '${IMAGE_RSTUDIO_PATH}' not found"
cd $IMAGE_DIR
singularity pull --name rstudio.sif docker://rocker/rstudio:latest
cd ~
fi
LOGS=~/log

# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} --time=${TIME} -N 1 -c 80 -o ${LOGS}/rstudio-server_${USER}_%j.log"
SCRIPT_INPUT="${USER} ${LOGIN_HOST} ${MOUNT_PROJECT} ${MOUNT_DATA}"

cd ${MOUNT_PROJECT}
BATCHID=$( sbatch $CMD_LINE_SLURM ~/batch/r_studio_server.sh $SCRIPT_INPUT )

LOG_NAME=~/log/rstudio-server_${USER}_${BATCHID}.log
COUNTER=0
while [ ! -f ${LOG_NAME} ] && [ ! $COUNTER -eq 30 ] ; do 
sleep 10
COUNTER=$(($COUNTER + 1))
if [ $COUNTER == 30 ] ; then
    scancel $BATCHID
    echo "timeout: no free slot available. Try again later"
fi 
done
sleep 5
if [ -f ${LOG_NAME} ] ; then
    cat ${LOG_NAME}
fi 

