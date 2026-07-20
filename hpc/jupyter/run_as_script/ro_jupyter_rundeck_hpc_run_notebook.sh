#!/bin/bash -x
#/ usage: start ?script? ?estimated_time? ?partition? ?version? ?mount_source1? ?mount_source2? ?mount_source3? ?read_only_sources?
set -eu
if [ $# -lt 8 ] ; then
  # echo command line
  echo $#
  echo ${@:1}
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
fi

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$(whoami)
SCRIPT_NAME=$1
TIME=$2
PARTITION=$3
VERSION_VIEW=$4
MOUNT_DATA_SOURCE1=$5 # e.g climate data
MOUNT_DATA_SOURCE2=${6} # e.g. project data
MOUNT_DATA_SOURCE3=${7} # e.g. other sources
READ_ONLY_SOURCES=${8}

#sbatch job name 
SBATCH_JOB_NAME="j_notebook"

# version mapping
# some versions will start with the name "legacy"
# remove it from the version name if it exists
VERSION=${VERSION_VIEW#legacy_}
echo "Requested version: $VERSION_VIEW, using version: $VERSION"

# check if additional directories are available (else set to none)
if [ ! -d ${MOUNT_DATA_SOURCE1} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE1}' not found"
MOUNT_DATA_SOURCE1=none
fi
if [ ! -d ${MOUNT_DATA_SOURCE2} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE2}' not found"
MOUNT_DATA_SOURCE2=none
fi
if [ ! -d ${MOUNT_DATA_SOURCE3} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE3}' not found"
MOUNT_DATA_SOURCE3=none
fi

# default mounts
MOUNT_DATA=/beegfs/common/data
MOUNT_PROJECT=/beegfs/$USER/
MOUNT_HOME=/home/$USER

# create required folder
WORKDIR=/beegfs/${USER}/jupyter_playground${VERSION}
LOGS=$WORKDIR/log
JWORK=$WORKDIR/jupyter_work


# check if selected playground exists
if [ ! -d ${WORKDIR} ] ; then
    echo "Directory '${WORKDIR}' not found"
    exit 1
fi

# check if script name (e.g. path/test.ipynb) contains invalid characters
# only a-z, A-Z, 0-9, _ , / , . and - are allowed
if [[ ! $SCRIPT_NAME =~ ^[a-zA-Z0-9_/.-]+$ ]] ; then
echo "Invalid characters in script name"
exit 1
fi 
# check if script path is a relative path or an absolute path
if [[ $SCRIPT_NAME =~ ^/ ]] ; then
echo "Absolute path detected"
else
echo "Relative path detected"
SCRIPT_NAME=$WORKDIR/$SCRIPT_NAME
fi

# check if script exists
if [ ! -f ${SCRIPT_NAME} ] ; then
echo "File '${SCRIPT_NAME}' not found"
exit 1
fi

mkdir -p -m 700 $LOGS
mkdir -p $JWORK

# get jupyter as prepared docker image
IMAGE_DIR=/beegfs/common/singularity/python
SINGULARITY_IMAGE=${VERSION}.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
fi

# prepare resource request based on partition choice, default is 80vCPUs-80gb-RAM
HPC_PARTITION="--partition=compute,highmem"
CORES=80
MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
GFX_SUPPORT="false"
#tiny-2vCPUs-2gb-RAM,
if [ $PARTITION == "tiny-2vCPUs-2gb-RAM" ] ; then 
  CORES=2
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 2GB
#10vCPUs-10gb-RAM,
elif [ $PARTITION == "10vCPUs-10gb-RAM" ] ; then 
  CORES=10
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 10GB
#40vCPUs-40gb-RAM,
elif [ $PARTITION == "40vCPUs-40gb-RAM" ] ; then 
  CORES=40
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 40GB
#80vCPUs-80gb-RAM,
elif [ $PARTITION == "80vCPUs-80gb-RAM" ] ; then 
  CORES=80
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
#fat-40vCPUs-360gb-RAM,
elif [ $PARTITION == "fat-40vCPUs-360gb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=40
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 360GB
#fat-80vCPUs-720gb-RAM,
elif [ $PARTITION == "fat-80vCPUs-720gb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=80
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 720GB
#fat-120vCPUs-1tb-RAM,
elif [ $PARTITION == "fat-120vCPUs-1tb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=120
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 1080GB
#compute-full-80vCPUs-90gb-RAM,
elif [ $PARTITION == "compute-full-80vCPUs-90gb-RAM" ] ; then 
  HPC_PARTITION="--partition=compute"
  CORES=80
  MEM_PER_CPU="" # Total memory: ~90GB
#highmem-full-80vCPUs-180gb-RAM,
elif [ $PARTITION == "highmem-full-80vCPUs-180gb-RAM" ] ; then 
  HPC_PARTITION="--partition=highmem"
  CORES=80
  MEM_PER_CPU="" # Total memory: ~180GB
#fat-full-160vCPUs-1.5tb-RAM
elif [ $PARTITION == "fat-full-160vCPUs-1.5tb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=160
  MEM_PER_CPU="" # Total memory: ~1.5TB
elif [ $PARTITION == "gpu-Tesla-V100" ] ; then 
   HPC_PARTITION="--partition=gpu -x gpu005"
   CORES=48
   MEM_PER_CPU="" # Total memory: ~90GB
   GFX_SUPPORT="true"
elif [ $PARTITION == "gpu-Nvidia-H100" ] ; then 
   HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
   CORES=128
   MEM_PER_CPU="" # Total memory: ~720GB
   GFX_SUPPORT="true"
fi
# tiny-2vCPUs-2gb-RAM,10vCPUs-10gb-RAM,40vCPUs-40gb-RAM,80vCPUs-80gb-RAM,fat-40vCPUs-360gb-RAM,fat-80vCPUs-720gb-RAM,fat-120vCPUs-1tb-RAM,compute-full-80vCPUs-90gb-RAM,highmem-full-80vCPUs-180gb-RAM,fat-full-160vCPUs-1.5tb-RAM,gpu-Tesla-V100,gpu-Nvidia-H100
RESOURCE_REQUEST="-c $CORES $MEM_PER_CPU $HPC_PARTITION" 

DATE=`date +%Y-%d-%B_%H%M%S`
LOG_NAME=${LOGS}/jupyter_lab_${DATE}_%j.log
# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${RESOURCE_REQUEST} --time=${TIME} -N 1 -o ${LOG_NAME} -e ${LOG_NAME}"
SCRIPT_INPUT="${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${WORKDIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${READ_ONLY_SOURCES} ${JWORK} ${IMAGE_PATH} ${VERSION} ${DATE} ${SCRIPT_NAME}"

echo $CMD_LINE_SLURM
echo $SCRIPT_INPUT

BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/run_notebook_${VERSION}.sh $SCRIPT_INPUT )

sleep 5
squeue -j $BATCHID

echo "Job submitted with ID: $BATCHID"




