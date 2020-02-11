#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_data? ?num_instance? ?version? ?estimated_time? ?mode? ?source? ?consumer? ?producer?
set -eu
[[ $# < 11 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_DATA_CLIMATE=$4
NUM_MONICA=$5
VERSION=$6
TIME=$7
MODE=$8
SCRIPT_SOURCE=$9
CONSUMER=${10}
PRODUCER=${11}

MONICA_PER_NODE=40

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="monica_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

#calculate distribution of monica on nodes
NUM_NODES=$(($NUM_MONICA / $MONICA_PER_NODE))

NUM_LEFT=$(($NUM_MONICA % $MONICA_PER_NODE))
if [ $NUM_LEFT -ne 0 ] ; then 
  NUM_NODES=$(($NUM_NODES + 1))
fi

NUM_WORKER=$(($NUM_MONICA / $NUM_NODES))
NUM_W_LEFT=$(($NUM_MONICA % $NUM_NODES))
if [ $NUM_W_LEFT -ne 0 ] ; then 
NUM_WORKER=$(($NUM_WORKER + 1))
fi
echo "Request Nodes: ${NUM_NODES}"
echo "Worker per Node: ${NUM_WORKER}"

# get monica image from docker
IMAGE_DIR=~/singularity/monica
SINGULARITY_IMAGE=monica-cluster_${VERSION}.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}
mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
cd $IMAGE_DIR
singularity pull docker://zalfrpm/monica-cluster:${VERSION}
cd ~
fi

# create output log
MOUNT_LOG_PROXY=~/log/supervisor/monica/proxy
mkdir -p $MOUNT_LOG_PROXY

MOUNT_LOG_WORKER=~/log/supervisor/monica/worker
mkdir -p $MOUNT_LOG_WORKER

DATE=`date +%Y-%d-%B_%H%M%S`
MONICA_WORKDIR=~/monica_run${DATE}
MONICA_OUT=/beegfs/rpm/projects/monica/out/monica_${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $MONICA_OUT

if [ $MODE == "git" ] ; then 
  # do a fresh git checkout
  mkdir $MONICA_WORKDIR
  cd  $MONICA_WORKDIR
  git clone $SCRIPT_SOURCE
  cd ~
elif [ $MODE == "folder" ] ; then
  # use folder on the cluster
  MONICA_WORKDIR=$SCRIPT_SOURCE
fi

# required nodes (1 monica proxy node)+(1 producer)+(1 consumer)+(n monica worker)
NUM_SLURM_NODES=$(($NUM_NODES + 3))
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} --time=${TIME} -N $NUM_SLURM_NODES -c 40 -o log/monica_proj-%j"
SCRIPT_INPUT="${MOUNT_DATA_CLIMATE} ${MONICA_WORKDIR} ${IMAGE_PATH} ${NUM_NODES} ${NUM_WORKER} ${MOUNT_LOG_PROXY} ${MOUNT_LOG_WORKER} ${CONSUMER} ${PRODUCER} ${SBATCH_JOB_NAME}"

BATCHID=$( sbatch $CMD_LINE_SLURM batch/sbatch_monica_project.sh $SCRIPT_INPUT )
DEPENDENCY="afterany:"$BATCHID
sbatch --dependency=$DEPENDENCY --job-name=${SBATCH_JOB_NAME}_CLEANUP --time=00:15:00 -o log/monica_project_cleanup-%j batch/sbatch_monica_project_cleanup.sh ${MODE} ${MONICA_WORKDIR} ${CONSUMER} ${MONICA_OUT}
