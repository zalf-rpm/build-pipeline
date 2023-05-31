#!/bin/bash 
#/ usage: start ?user? ?job_exec_id? ?host? ?mount_source1? ?mount_source2? ?mount_source3? ?estimated_time? ?partition? ?version? ?password? ?read_only_sources?
set -eu
[[ $# < 11 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
LOGIN_HOST=$3
TIME=$4
PARTITION=$5
VERSION=$6
PASSW=$7
MOUNT_DATA_SOURCE1=$8 # e.g climate data
MOUNT_DATA_SOURCE2=$9 # e.g. project data
MOUNT_DATA_SOURCE3=${10} # e.g. other sources
READ_ONLY_SOURCES=${11}

# fail if no password is given
if [ -z "$PASSW" ] ; then
    echo "No password given"
    exit 1
fi

#sbatch job name 
SBATCH_JOB_NAME="R_${USER}_${JOB_EXEC_ID}"

# get r-studio image from docker
IMAGE_DIR=/beegfs/common/singularity/R
SINGULARITY_IMAGE=rstudio_dev_${VERSION}.sif
IMAGE_RSTUDIO_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_RSTUDIO_PATH} ] ; then
echo "File '${IMAGE_RSTUDIO_PATH}' not found"
fi

MOUNT_PROJECT=/beegfs/$USER/
MOUNT_DATA=/beegfs/common/data
WORKDIR=/beegfs/${USER}/R_playground${VERSION}
LOGS=$WORKDIR/log

mkdir -p -m 700 $WORKDIR
mkdir -p -m 700 $LOGS

HPC_PARTITION="--partition=compute"
CORES=80
if [ $PARTITION == "highmem" ] ; then 
  HPC_PARTITION="--partition=highmem"
  CORES=80
elif [ $PARTITION == "gpu" ] ; then 
  HPC_PARTITION="--partition=gpu"
  CORES=48
elif [ $PARTITION == "fat" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=160
fi

if [ ! -d ${MOUNT_DATA_SOURCE1} ] ; then
echo "Directory '${MOUNT_DATA_SOURCE1}' not found"
MOUNT_DATA_SOURCE1=none
fi
if [ ! -d ${MOUNT_DATA_SOURCE2} ] ; then
echo "Directory '${MOUNT_DATA_SOURCE2}' not found"
MOUNT_DATA_SOURCE2=none
fi
if [ ! -d ${MOUNT_DATA_SOURCE3} ] ; then
echo "Directory '${MOUNT_DATA_SOURCE3}' not found"
MOUNT_DATA_SOURCE3=none
fi

# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c $CORES -o ${LOGS}/rstudio-server_${USER}_%j.log"
SCRIPT_INPUT="${USER} ${LOGIN_HOST} ${MOUNT_PROJECT} ${MOUNT_DATA} ${WORKDIR} ${IMAGE_RSTUDIO_PATH} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${PASSW} ${READ_ONLY_SOURCES}"

cd ${WORKDIR}
BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/r_studio_server${VERSION}.sh $SCRIPT_INPUT )

LOG_NAME=${LOGS}/rstudio-server_${USER}_${BATCHID}.log
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

