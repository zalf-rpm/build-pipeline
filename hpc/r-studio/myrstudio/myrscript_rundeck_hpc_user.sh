#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?mount_source1? ?mount_source2? ?mount_source3? ?estimated_time? ?partition? ?version? ?read_only_sources?
set -eu
echo $#
if [ $# -lt 9 ] ; then
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
fi

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
TIME=$2
PARTITION=$3
VERSION=$4
MOUNT_DATA_SOURCE1=$5 # e.g climate data
MOUNT_DATA_SOURCE2=$6 # e.g. project data
MOUNT_DATA_SOURCE3=${7} # e.g. other sources
READ_ONLY_SOURCES=${8}
SCRIPT_NAME=$9
PARAMS=${@:10}

SBATCH_JOB_NAME="R_script_playground"

MOUNT_PROJECT=/beegfs/$USER/
MOUNT_DATA=/beegfs/common/data
WORKDIR=/beegfs/${USER}/R_playground${VERSION}
LOGS=$WORKDIR/log

mkdir -p -m 700 $WORKDIR
mkdir -p -m 700 $LOGS

# get r-studio image from docker
IMAGE_DIR=/beegfs/common/singularity/R
SINGULARITY_IMAGE=rstudio_dev_${VERSION}.sif
IMAGE_RSTUDIO_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_RSTUDIO_PATH} ] ; then
echo "File '${IMAGE_RSTUDIO_PATH}' not found"
fi

HPC_PARTITION="--partition=compute"
CORES=80
echo "warning..."
if [ $PARTITION == "highmem" ] ; then 
   HPC_PARTITION="--partition=highmem"
   CORES=80
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
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c $CORES -o ${LOGS}/rscript_${USER}_%j.log"
SCRIPT_INPUT="${USER} ${MOUNT_PROJECT} ${MOUNT_DATA} ${WORKDIR} ${IMAGE_RSTUDIO_PATH} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${READ_ONLY_SOURCES}"
SCRIPT_INPUT="${SCRIPT_INPUT} ${SCRIPT_NAME} ${PARAMS}"

# script version - take first 2 decimals from VERSION
VERSION_SHORT=$(echo $VERSION | cut -d. -f1,2)

# check if script exists
if [ ! -e /beegfs/common/batch/r_script${VERSION_SHORT}.sh ] ; then
  echo "Script /beegfs/common/batch/r_script${VERSION_SHORT}.sh not found"
  exit 1
fi

cd ${WORKDIR}
BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/r_script${VERSION_SHORT}.sh $SCRIPT_INPUT )


