#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?estimated_time? ?partition? ?version? ?port? ?mount_source1? ?mount_source2? ?mount_source3? ?read_only_sources? 

set -eu
[[ $# < 11 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1 
JOB_EXEC_ID=$2 # from rundeck, for matching the job with the rundeck job execution
LOGIN_HOST=$3 # login host for the HPC cluster, e.g. to print the login command for the user to connect to the HPC cluster
TIME=$4 # timelimit for the job, e.g. 2:00:00 for 2 hours
RESOURCES=$5 # resources definition for the job, maps to CPU, GPU, memory 
VERSION=$6 # version of the base image to use, e.g. 0.4 for ai-harness_0.4.sif
PROJECT_DIR=$7 # project directory to mount in the container, e.g. /beegfs/$USER/my_project
MOUNT_DATA_SOURCE1=$8 # e.g climate data (optional mount source, can be none)
MOUNT_DATA_SOURCE2=${9} # e.g. project data (optional)
MOUNT_DATA_SOURCE3=${10} # e.g. other sources (optional)
MOUNT_DATA_OUT=${11} # e.g. output data directory (optional, can be none)

LOGS=/beegfs/$USER/ide/logs
LAUNCH_DIR=/beegfs/$USER/ide/.launch_instructions
mkdir -p $LOGS
mkdir -p $LAUNCH_DIR

# TBD: only project directory and output data directory should be mounted as read-write, 
# all other directories should be mounted as read-only
# TODO: check with users later

# check if additional directories are available (else set to none)
# mounted directories need to exist and be accessible by the user, otherwise the job will fail
if [ ! -d ${PROJECT_DIR} ] ; then
echo "Project directory '${PROJECT_DIR}' not found"
exit 1
fi
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
if [ ! -d ${MOUNT_DATA_OUT} ] ; then
echo "Output data directory '${MOUNT_DATA_OUT}' not found"
MOUNT_DATA_OUT=none
fi
# permission check: if the directory is not accessible by the user, it will be set to none
if [ ! -r ${MOUNT_DATA_SOURCE1} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE1}' is not readable by the user"
MOUNT_DATA_SOURCE1=none
fi
if [ ! -r ${MOUNT_DATA_SOURCE2} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE2}' is not readable by the user"
MOUNT_DATA_SOURCE2=none
fi
if [ ! -r ${MOUNT_DATA_SOURCE3} ] ; then
echo "Additional directory '${MOUNT_DATA_SOURCE3}' is not readable by the user"
MOUNT_DATA_SOURCE3=none
fi
# check for rw permission for the output data directory, if not readable, set to none
if [ ! -r ${MOUNT_DATA_OUT} ] || [ ! -w ${MOUNT_DATA_OUT} ] ; then
echo "Output data directory '${MOUNT_DATA_OUT}' must be readable and writable by the user"
MOUNT_DATA_OUT=none
fi
if [ ! -r ${PROJECT_DIR} ] || [ ! -w ${PROJECT_DIR} ] ; then
echo "Project directory '${PROJECT_DIR}' must be readable and writable by the user"
exit 1
fi

# get base image as singularity image path
IMAGE_DIR=/beegfs/common/singularity/ai-harness
SINGULARITY_IMAGE=${VERSION}.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
exit 1
fi

# prepare resource request based on partition choice, default is 80vCPUs-80gb-RAM
HPC_PARTITION="--partition=compute,highmem"
CORES=80
MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
GFX_SUPPORT="false"
#tiny-2vCPUs-2gb-RAM,
if [ $RESOURCES == "tiny-2vCPUs-2gb-RAM" ] ; then 
  CORES=2
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 2GB
#10vCPUs-10gb-RAM,
elif [ $RESOURCES == "10vCPUs-10gb-RAM" ] ; then 
  CORES=10
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 10GB
#40vCPUs-40gb-RAM,
elif [ $RESOURCES == "40vCPUs-40gb-RAM" ] ; then 
  CORES=40
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 40GB
#80vCPUs-80gb-RAM,
elif [ $RESOURCES == "80vCPUs-80gb-RAM" ] ; then 
  CORES=80
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
#fat-40vCPUs-360gb-RAM,
elif [ $RESOURCES == "fat-40vCPUs-360gb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=40
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 360GB
#fat-80vCPUs-720gb-RAM,
elif [ $RESOURCES == "fat-80vCPUs-720gb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=80
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 720GB
#fat-120vCPUs-1tb-RAM,
elif [ $RESOURCES == "fat-120vCPUs-1tb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=120
  MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 1080GB
#compute-full-80vCPUs-90gb-RAM,
elif [ $RESOURCES == "compute-full-80vCPUs-90gb-RAM" ] ; then 
  HPC_PARTITION="--partition=compute"
  CORES=80
  MEM_PER_CPU="" # Total memory: ~90GB
#highmem-full-80vCPUs-180gb-RAM,
elif [ $RESOURCES == "highmem-full-80vCPUs-180gb-RAM" ] ; then 
  HPC_PARTITION="--partition=highmem"
  CORES=80
  MEM_PER_CPU="" # Total memory: ~180GB
#fat-full-160vCPUs-1.5tb-RAM
elif [ $RESOURCES == "fat-full-160vCPUs-1.5tb-RAM" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=160
  MEM_PER_CPU="" # Total memory: ~1.5TB
elif [ $RESOURCES == "gpu-Tesla-V100" ] ; then 
   HPC_PARTITION="--partition=gpu -x gpu005"
   CORES=48
   MEM_PER_CPU="" # Total memory: ~90GB
elif [ $RESOURCES == "gpu-Nvidia-H100" ] ; then 
   HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
   CORES=128
   MEM_PER_CPU="" # Total memory: ~720GB
fi

RESOURCE_REQUEST="-c $CORES $MEM_PER_CPU $HPC_PARTITION" 

DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOG_NAME=${LOGS}/ai_harness_${DATE}_%j.log

SBATCH_CMD=" --parsable --job-name=$JOB_NAME --time=$TIME -N 1 $RESOURCE_REQUEST -o ${LOG_NAME} -e ${LOG_NAME} "
SCRIPT_INPUT="${PROJECT_DIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${MOUNT_OUTPUT} ${IMAGE_PATH} ${LOGIN_HOST} ${LAUNCH_DIR}"

BATCHID=$(sbatch $SBATCH_CMD /beegfs/common/batch/sbatch_start_ide_container_${VERSION}.sh ${SCRIPT_INPUT} )

# wait for launch file to be created by sbatch script, check every 5 seconds, and print launch instructions 
# for ssh tunnel 
sleep 5
LAUNCH_FILE=$LAUNCH_DIR/${BATCHID}.rundeck

# count to 30 or till a launch file is created, 
# then timeout and cancel job if no launch file is created
COUNTER=0
while [ ! -f ${LAUNCH_FILE} ] && [ ! $COUNTER -eq 30 ] ; do 
sleep 5
COUNTER=$(($COUNTER + 1))
if [ $COUNTER == 30 ] ; then
    scancel $BATCHID
    echo "timeout: no free slot available. Try again later"
    exit 1
fi 
done

# print launch instructions for ssh tunnel and access
if [ -f ${LAUNCH_FILE} ] ; then
    cat ${LAUNCH_FILE}
else
    echo "Launch instructions file not found: ${LAUNCH_FILE}"
    echo "Check if job is running with a different version"
fi 