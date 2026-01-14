#!/bin/bash -x

USER=username # enter your hpc username here
TIME=1-12:00:00 # 1 day 12 hours
PARTITION=compute # compute, highmem, fat
VERSION=4.4.1 # R version (valid: 4.2.2, 4.2.3, 4.2.4, 4.4.1, 4.4.1_gpu_1)
MOUNT_DATA_SOURCE1=none # e.g climate data
MOUNT_DATA_SOURCE2=none # e.g. project data
MOUNT_DATA_SOURCE3=none # e.g. other sources
READ_ONLY_SOURCES=true
SCRIPT_NAME=example_rscript.R # script to run inside R
PARAMS=${@}  # parameters passed to the R script

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

echo sbatch $CMD_LINE_SLURM /beegfs/common/batch/r_script${VERSION_SHORT}.sh $SCRIPT_INPUT
BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/r_script${VERSION_SHORT}.sh $SCRIPT_INPUT )


