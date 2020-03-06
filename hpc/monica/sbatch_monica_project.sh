#!/bin/bash -x
#SBATCH --partition=compute
#SBATCH --cpus-per-task=40

MOUNT_DATA_CLIMATE=${1}
MOUNT_DATA_PROJECT=${2}
MONICA_WORKDIR=${3}
SINGULARITY_MONICA_IMAGE=${4}
SINGULARITY_PYTHON_IMAGE=${5}
NUM_NODES=${6}
NUM_WORKER=${7}
MOUNT_LOG_PROXY=${8}
MOUNT_LOG_WORKER=${9}
MONICA_OUT=${10}
CONSUMER=${11}
PRODUCER=${12}
SBATCH_JOB_NAME=${12}

echo "SLURM NODES" ${SLURM_JOB_NODELIST}

NODE_LIST=$( ./batch/SplitSlurmNodes ${SLURM_JOB_NODELIST} )

IFS=',' read -ra ADDR <<< "${NODE_LIST}"
IFS=' '

NODE_PRODUCER=${ADDR[0]}
NODE_CONSUMER=${ADDR[1]}
NODE_PROXY=${ADDR[2]}
NODE_ARRAY_WORKER=("${ADDR[@]:3}")

echo "worker array: " $NODE_ARRAY_WORKER
DATE=`date +%Y-%d-%B_%H%M%S`

# start proxy
$MOUNT_LOG_PROXY=$MOUNT_LOG_PROXY/${DATE}
mkdir -p $MOUNT_LOG_PROXY
srun --exclusive -w $NODE_PROXY -N1 -n1 -o ~/log/monica_proxy_%j batch/sbatch_monica_proxy.sh ${SINGULARITY_MONICA_IMAGE} $MOUNT_LOG_PROXY &


# start worker
$MOUNT_LOG_WORKER=$MOUNT_LOG_WORKER/${DATE}
mkdir -p $MOUNT_LOG_WORKER
for node in "${NODE_ARRAY_WORKER[@]}"; do
    echo "worker: " ${node}
    srun --exclusive -w ${node} -N1 -n1 -o ~/log/monica_worker_${node}_%j batch/sbatch_monica_worker.sh $MOUNT_DATA_CLIMATE $SINGULARITY_MONICA_IMAGE $NUM_WORKER "${NODE_PROXY}.opa" $MOUNT_LOG_WORKER &
done


PATH_TO_CONSUMER="${CONSUMER%/*}"
FILENAME_CONSUMER="${CONSUMER##*/}"

# start consumer
srun --exclusive -w ${NODE_CONSUMER} -N1 -n1 -o ~/log/monica_proj_clog-%j -e ~/log/monica_proj_eclog-%j batch/sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $MONICA_WORKDIR/$PATH_TO_CONSUMER $FILENAME_CONSUMER mode=remoteConsumer-remoteMonica server=$NODE_PROXY port=7777 &
consumer_process_id=$!

PATH_TO_PRODUCER="${PRODUCER%/*}"
FILENAME_PRODUCER="${PRODUCER##*/}"

# start producer
srun --exclusive -w ${NODE_PRODUCER} -N1 -n1 -o ~/log/monica_proj_plog-%j -e ~/log/monica_proj_eplog-%j batch/sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $MONICA_WORKDIR/$PATH_TO_PRODUCER $FILENAME_PRODUCER mode=remoteProducer-remoteMonica server=$NODE_PROXY server-port=6666 &
wait $consumer_process_id
