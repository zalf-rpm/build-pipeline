#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_climate_data? ?mount_project_data? ?num_instance? ?version? ?estimated_time? ?estimated_consumer_size? ?estimated_producer_size? ?estimated_proxy_size? ?CHECKOUT_MODE? ?source? ?consumer? ?producer?
set -eu
[[ $# < 16 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=~/.conda/envs/git/bin:$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_DATA_CLIMATE=$4
MOUNT_DATA_PROJECT=$5
NUM_MONICA=$6
VERSION=$7
PYTHON_VERSION=$8
TIME=$9
EST_CONSUMER=${10}
EST_PRODUCER=${11}
EST_PROXY=${12}

CHECKOUT_MODE=${13} # git or folder
PROJECT_SOURCE=${14} # git url or folder path
CONSUMER=${15} # path to consumer script
PRODUCER=${16} # path to producer script
RUN_SETUPS=${17} # run setup numbers [, separated]
SETUPS_FILE=${18} # path to setups file
# all rest of command line arguments
ADDITIONAL_PARAMS="${@:19}" # consumer/producer additional parameters

# estimated resource usage (tiny/normal/high)
# check estimated resource usage and set parameters accordingly
CONSUMER_CPU="2" # it is a python script, not multi threaded
CONSUMER_MEMORY="4G"
CONSUMER_PARTITION="compute"
if [ $EST_CONSUMER == "tiny" ] ; then
  CONSUMER_MEMORY="4G"
elif [ $EST_CONSUMER == "normal" ] ; then 
  CONSUMER_MEMORY="35G"
elif [ $EST_CONSUMER == "high" ] ; then 
  CONSUMER_MEMORY="75G"
  CONSUMER_PARTITION="highmem"
else
  echo "Error: Unknown estimated consumer resource usage: $EST_CONSUMER" >&2
  exit 1
fi
# --cpus-per-task=4 --mem-per-cpu=16g --ntasks=1

CONSUMER_SLURM_PARAMS="--cpus-per-task=${CONSUMER_CPU} --mem-per-cpu=${CONSUMER_MEMORY} --ntasks=1 --partition=${CONSUMER_PARTITION}"

PRODUCER_CPU="2" # it is a python script, not multi threaded
PRODUCER_MEMORY="4G"
PRODUCER_PARTITION="compute"
if [ $EST_PRODUCER == "tiny" ] ; then
  PRODUCER_MEMORY="4G"
elif [ $EST_PRODUCER == "normal" ] ; then 
  PRODUCER_MEMORY="35G"
elif [ $EST_PRODUCER == "high" ] ; then 
  PRODUCER_MEMORY="75G"
  PRODUCER_PARTITION="highmem"
else
  echo "Error: Unknown estimated producer resource usage: $EST_PRODUCER" >&2
  exit 1
fi
PRODUCER_SLURM_PARAMS="--cpus-per-task=${PRODUCER_CPU} --mem-per-cpu=${PRODUCER_MEMORY} --ntasks=1 --partition=${PRODUCER_PARTITION}"

PROXY_CPU="4" # monica proxy 
PROXY_MEMORY="8G"
PROXY_PARTITION="compute"
if [ $EST_PROXY == "tiny" ] ; then
  PROXY_MEMORY="8G"
elif [ $EST_PROXY == "normal" ] ; then 
  PROXY_MEMORY="35G"
elif [ $EST_PROXY == "high" ] ; then 
  PROXY_MEMORY="75G"
  PROXY_PARTITION="highmem"
else
  echo "Error: Unknown estimated proxy resource usage: $EST_PROXY" >&2
  exit 1
fi
PROXY_SLURM_PARAMS="--cpus-per-task=${PROXY_CPU} --mem-per-cpu=${PROXY_MEMORY} --ntasks=1 --partition=${PROXY_PARTITION}"

# resolve path
MOUNT_DATA_CLIMATE=$( realpath $MOUNT_DATA_CLIMATE )
MOUNT_DATA_PROJECT=$( realpath $MOUNT_DATA_PROJECT )
if  [[ $MOUNT_DATA_CLIMATE == /home/rpm* ]] ;
then
    echo "access denied"
    exit 1
fi
if  [[ $MOUNT_DATA_PROJECT == /home/rpm* ]] ;
then
    echo "access denied"
    exit 1
fi


# make sure the job name does not contain any other characters than alphanumeric and _
JOB_NAME=$( echo $JOB_NAME | tr -cd '[:alnum:]_')
# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="${USER}_monica_${JOB_NAME}_${JOB_EXEC_ID}"

# max number of monica instances per node
MONICA_PER_NODE=40
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
WORKER_SLURM_PARAMS="--cpus-per-task=${MONICA_PER_NODE} --mem-per-cpu=2g --ntasks=${NUM_NODES} --partition=compute"


# get monica image from docker
IMAGE_DIR=~/singularity/monica
SINGULARITY_IMAGE=monica-cluster_${VERSION}.sif
IMAGE_MONICA_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}
mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_MONICA_PATH} ] ; then
echo "File '${IMAGE_MONICA_PATH}' not found"
cd $IMAGE_DIR
singularity pull docker://zalfrpm/monica-cluster:${VERSION}
cd ~
fi

IMAGE_DIR_PYTHON=~/singularity/python
SINGULARITY_PYTHON_IMAGE=${PYTHON_VERSION}.sif #python3.7_1.0.sif
IMAGE_PYTHON_PATH=${IMAGE_DIR_PYTHON}/${SINGULARITY_PYTHON_IMAGE}
mkdir -p $IMAGE_DIR_PYTHON
if [ ! -e ${IMAGE_PYTHON_PATH} ] ; then
  echo "File '${IMAGE_PYTHON_PATH}' not found"
  cd $IMAGE_DIR_PYTHON
  if [ $PYTHON_VERSION == "python3.7_1.0" ] ; then 
    singularity pull docker://zalfrpm/python3.7:1.0
  elif [ $PYTHON_VERSION == "python3.10_3" ] ; then 
    singularity pull docker://zalfrpm/python3.10:3
  fi
  cd ~
fi


# create output log
MOUNT_LOG_PROXY=~/log/supervisor/monica/proxy
mkdir -p $MOUNT_LOG_PROXY

MOUNT_LOG_WORKER=~/log/supervisor/monica/worker
mkdir -p $MOUNT_LOG_WORKER

DATE=`date +%Y-%d-%B_%H%M%S`
MONICA_WORKDIR=/beegfs/rpm/projects/monica/projectcheckouts/${USER}_${JOB_EXEC_ID}_${DATE}
MONICA_OUT=/beegfs/rpm/projects/monica/out/${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $MONICA_OUT

MONICA_LOG=/beegfs/rpm/projects/monica/log/${USER}_${JOB_EXEC_ID}_${DATE}
mkdir $MONICA_LOG

if [ $CHECKOUT_MODE == "git" ] ; then 
  # do a fresh git checkout
  mkdir $MONICA_WORKDIR
  cd  $MONICA_WORKDIR
  git clone $PROJECT_SOURCE
  git clone https://github.com/zalf-rpm/monica-parameters.git
  git clone https://github.com/zalf-rpm/mas-infrastructure.git
  cd ~
elif [ $CHECKOUT_MODE == "folder" ] ; then
  # use folder on the cluster
  MONICA_WORKDIR=$( realpath $PROJECT_SOURCE )
  if  [[ $MONICA_WORKDIR == /home/rpm* ]] ;
  then
      echo "access denied"
      exit 1
  fi
fi


# Example sbatch for multiple resource request:
# sbatch --cpus-per-task=4 --mem-per-cpu=16g --ntasks=1 : \
#          --cpus-per-task=2 --mem-per-cpu=1g  --ntasks=8 my.bash

# required resources (1 monica proxy)+(1 producer)+(1 consumer)+(n monica worker)
CMD_LINE_SLURM="${CONSUMER_SLURM_PARAMS} : ${PRODUCER_SLURM_PARAMS} : ${PROXY_SLURM_PARAMS} : ${WORKER_SLURM_PARAMS} "
# other sbatch parameters
CMD_LINE_SLURM="$CMD_LINE_SLURM --parsable --job-name=${SBATCH_JOB_NAME} --time=${TIME} -o ${MONICA_LOG}/monica_proj-%j"
# command line input for the monica project sbatch script
SCRIPT_INPUT="${MOUNT_DATA_CLIMATE} ${MOUNT_DATA_PROJECT} ${MONICA_WORKDIR} ${IMAGE_MONICA_PATH} ${IMAGE_PYTHON_PATH} ${NUM_NODES} ${NUM_WORKER} ${MONICA_LOG} ${MOUNT_LOG_PROXY} ${MOUNT_LOG_WORKER} $MONICA_OUT ${CONSUMER} ${PRODUCER} ${RUN_SETUPS} ${SETUPS_FILE} ${ADDITIONAL_PARAMS}"

echo "sbatch $CMD_LINE_SLURM batch/ro_sbatch_monica_project.sh $SCRIPT_INPUT"

#BATCHID=$( sbatch $CMD_LINE_SLURM batch/ro_sbatch_monica_project.sh $SCRIPT_INPUT )

#DEPENDENCY="afterany:"$BATCHID
#sbatch --dependency=$DEPENDENCY --job-name=${SBATCH_JOB_NAME}_CLEANUP --time=00:15:00 -o log/monica_project_cleanup-%j batch/ro_sbatch_monica_project_cleanup.sh ${CHECKOUT_MODE} ${MONICA_WORKDIR} 
