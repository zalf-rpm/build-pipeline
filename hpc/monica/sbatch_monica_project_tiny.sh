#!/bin/bash -x
#SBATCH --exclusive

MOUNT_DATA_CLIMATE=${1}
MOUNT_DATA_PROJECT=${2}
MONICA_WORKDIR=${3}
SINGULARITY_MONICA_IMAGE=${4}
SINGULARITY_PYTHON_IMAGE=${5}
NUM_NODES=${6}
NUM_WORKER=${7}
MONICA_LOG=${8}
MOUNT_LOG_PROXY=${9}
MOUNT_LOG_WORKER=${10}
MONICA_OUT=${11}
CONSUMER=${12}
PRODUCER=${13}
SBATCH_JOB_NAME=${14}
RUN_SETUPS=${15}
SETUPS_FILE=${16}

CURRENT_NODE=localhost

# cap number of worker nodes to 40
if [ "$NUM_NODES" -gt 40 ]; then
    NUM_NODES=40
fi
NODE_PROXY=${CURRENT_NODE}

# start proxy and worker on the same node
sh batch/sbatch_monica_worker_prox_tiny.sh $MOUNT_DATA_CLIMATE $SINGULARITY_MONICA_IMAGE $NUM_WORKER $MONICA_LOG &

MONICA_PARAMS=$MONICA_WORKDIR/monica-parameters
MAS_INFRASTRUCTURE=$MONICA_WORKDIR/mas-infrastructure

PATH_TO_CONSUMER="${CONSUMER%/*}"
FILENAME_CONSUMER="${CONSUMER##*/}"

# start consumer
srun -o ${MONICA_LOG}/monica_proj_clog-%j -e ${MONICA_LOG}/monica_proj_eclog-%j batch/sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $MONICA_PARAMS $MAS_INFRASTRUCTURE $MONICA_WORKDIR/$PATH_TO_CONSUMER $FILENAME_CONSUMER mode=remoteConsumer-remoteMonica server=$NODE_PROXY port=7777 &
consumer_process_id=$!

PATH_TO_PRODUCER="${PRODUCER%/*}"
FILENAME_PRODUCER="${PRODUCER##*/}"

# start producer
srun -o ${MONICA_LOG}/monica_proj_plog-%j -e ${MONICA_LOG}/monica_proj_eplog-%j batch/sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $MONICA_PARAMS $MAS_INFRASTRUCTURE $MONICA_WORKDIR/$PATH_TO_PRODUCER $FILENAME_PRODUCER mode=remoteProducer-remoteMonica server=$NODE_PROXY server-port=6666  run-setups=$RUN_SETUPS setups-file=$SETUPS_FILE &
wait $consumer_process_id