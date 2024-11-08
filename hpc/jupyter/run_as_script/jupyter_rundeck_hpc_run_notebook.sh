#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?script? ?estimated_time? ?partition? ?version? ?mount_source1? ?mount_source2? ?mount_source3? ?read_only_sources?
set -eu
if [ $# -lt 10 ] ; then
  # echo command line
  echo $#
  echo ${@:1}
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
fi

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
SCRIPT_NAME=$3
TIME=$4
PARTITION=$5
VERSION=$6
MOUNT_DATA_SOURCE1=$7 # e.g climate data
MOUNT_DATA_SOURCE2=${8} # e.g. project data
MOUNT_DATA_SOURCE3=${9} # e.g. other sources
READ_ONLY_SOURCES=${10}

#sbatch job name 
SBATCH_JOB_NAME="jp_run_as_script"



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

HPC_PARTITION="--partition=compute"
CORES=80
echo "Partition: $PARTITION"
if [ $PARTITION == "highmem" ] ; then 
  HPC_PARTITION="--partition=highmem"
  CORES=80
  echo "cores: $CORES"
elif [ $PARTITION == "gpu" ] ; then 
  HPC_PARTITION="--partition=gpu"
  CORES=48
  echo "cores: $CORES"
elif [ $PARTITION == "fat" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=160
  echo "cores: $CORES"
fi

DATE=`date +%Y-%d-%B_%H%M%S`

# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c ${CORES} -o ${LOGS}/jupyter_lab_${DATE}_%j.log"
SCRIPT_INPUT="${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${WORKDIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${READ_ONLY_SOURCES} ${JWORK} ${IMAGE_PATH} ${VERSION} ${DATE} ${SCRIPT_NAME}"

echo $CMD_LINE_SLURM
echo $SCRIPT_INPUT

BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/run_notebook_${VERSION}.sh $SCRIPT_INPUT )

sleep 5
squeue -j $BATCHID

echo "Job submitted with ID: $BATCHID"




