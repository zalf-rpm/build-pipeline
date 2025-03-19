#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_climate_data? ?mount_project_data? ?num_instance? ?version? ?estimated_time? ?mode? ?usehighmem? ?source? ?python_script?
set -eu
[[ $# < 15 ]] && {
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
MODE=${10}
USEHIGHMEM=${11}
SCRIPT_SOURCE=${12}
PYTHON_SCRIPT=${13}
MAS_TAG=${14}
SHARED_ID=${15}
shift 15
SCRIPT_PARAMETERS=$@

MONICA_PER_NODE=80

# check if mas tag is empty
if [ -z "$MAS_TAG" ] ; then 
    MAS_TAG="main"
fi

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


# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

HPC_PARTITION="--partition=compute"
if [ $USEHIGHMEM == "true" ] ; then 
  HPC_PARTITION="--partition=highmem"
fi

#sbatch job name 
SBATCH_JOB_NAME="${USER}_monica_${JOB_NAME}_${JOB_EXEC_ID}"

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
  exit 1
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

if [ $MODE == "git" ] ; then 
  # do a fresh git checkout
  mkdir $MONICA_WORKDIR
  cd  $MONICA_WORKDIR

  # get script source
  git clone $SCRIPT_SOURCE
  # check if tag is main
  if [ $MAS_TAG == "main" ] ; then 
    git clone https://github.com/zalf-rpm/mas-infrastructure.git
  else
    # check if tag exists on git for mas-infrastructure
    git clone --depth 1 --branch $MAS_TAG https://github.com/zalf-rpm/mas-infrastructure.git
  fi

  cd ~
elif [ $MODE == "folder" ] ; then
  # use folder on the cluster
  MONICA_WORKDIR=$( realpath $SCRIPT_SOURCE )
  if  [[ $MONICA_WORKDIR == /home/rpm* ]] ;
  then
      echo "access denied"
      exit 1
  fi
fi

# required nodes (0 monica proxy node)+(1 python script)+(n monica worker)
NUM_SLURM_NODES=$(($NUM_NODES + 1))
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} --time=${TIME} $HPC_PARTITION -N $NUM_SLURM_NODES -c 80 -o ${MONICA_LOG}/monica_proj-%j"
SCRIPT_INPUT="${MOUNT_DATA_CLIMATE} ${MOUNT_DATA_PROJECT} ${MONICA_WORKDIR} ${IMAGE_MONICA_PATH} ${IMAGE_PYTHON_PATH} ${NUM_NODES} ${NUM_WORKER} ${MONICA_LOG} ${MOUNT_LOG_PROXY} ${MOUNT_LOG_WORKER} $MONICA_OUT ${PYTHON_SCRIPT} ${SBATCH_JOB_NAME} ${SHARED_ID} ${SCRIPT_PARAMETERS}"

BATCHID=$( sbatch $CMD_LINE_SLURM batch/sbatch_monica_based_python_script_opt.sh $SCRIPT_INPUT )
DEPENDENCY="afterany:"$BATCHID
sbatch --dependency=$DEPENDENCY --job-name=${SBATCH_JOB_NAME}_CLEANUP --time=00:15:00 -o log/monica_project_cleanup-%j batch/sbatch_monica_project_cleanup.sh ${MODE} ${MONICA_WORKDIR} 
