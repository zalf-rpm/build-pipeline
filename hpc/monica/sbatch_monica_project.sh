#!/bin/bash -x
#SBATCH --partition=compute
#SBATCH --cpus-per-task=40

MOUNT_DATA_CLIMATE=${1}
MONICA_WORKDIR=${2}
SINGULARITY_IMAGE=${3}
NUM_NODES=${4}
NUM_WORKER=${5}
MOUNT_LOG_PROXY=${6}
MOUNT_LOG_WORKER=${7}
CONSUMER=${8}
PRODUCER=${9}
SBATCH_JOB_NAME=${10}

echo "SLURM NODES" ${SLURM_JOB_NODELIST}

NODE_LIST=$( ./batch/SplitSlurmNodes ${SLURM_JOB_NODELIST} )

IFS=',' read -ra ADDR <<< "${NODE_LIST}"
IFS=' '

NODE_PRODUCER=${ADDR[0]}
NODE_CONSUMER=${ADDR[1]}
NODE_PROXY=${ADDR[2]}
NODE_ARRAY_WORKER=("${ADDR[@]:3}")

echo "worker array: " $ADDR
DATE=`date +%Y-%d-%B_%H%M%S`

# start proxy
$MOUNT_LOG_PROXY=$MOUNT_LOG_PROXY/${DATE}
mkdir -p $MOUNT_LOG_PROXY
srun --exclusive -w $NODE_PROXY -N1 -n1 -o ~/log/monica_proxy_%j batch/sbatch_monica_proxy.sh ${SINGULARITY_IMAGE} $MOUNT_LOG_PROXY &


# start worker
$MOUNT_LOG_WORKER=$MOUNT_LOG_WORKER/${DATE}
mkdir -p $MOUNT_LOG_WORKER
for node in ${NODE_ARRAY_WORKER}; do

    echo "worker: " ${node}
    srun --exclusive -w ${node} -N1 -n1 -o ~/log/monica_worker_${node}_%j batch/sbatch_monica_worker.sh $MOUNT_DATA_CLIMATE $SINGULARITY_IMAGE $NUM_WORKER "${NODE_PROXY}.opa" $MOUNT_LOG_WORKER &
done


PATH_TO_CONSUMER="${CONSUMER%/*}"
FILENAME_CONSUMER="${CONSUMER##*/}"

cd $MONICA_WORKDIR/$PATH_TO_CONSUMER
# start consumer
srun --exclusive -w ${NODE_CONSUMER} -N1 -n1 -o ~/log/monica_proj_clog-%j -e ~/log/monica_proj_eclog-%j python $FILENAME_CONSUMER mode=remoteConsumer-remoteMonica server=$NODE_PROXY port=7777 &
consumer_process_id=$!

PATH_TO_PRODUCER="${PRODUCER%/*}"
FILENAME_PRODUCER="${PRODUCER##*/}"

cd $MONICA_WORKDIR/$PATH_TO_PRODUCER
# start producer
srun --exclusive -w ${NODE_PRODUCER} -N1 -n1 -o ~/log/monica_proj_plog-%j -e ~/log/monica_proj_eplog-%j python $FILENAME_PRODUCER mode=remoteProducer-remoteMonica server=$NODE_PROXY server-port=6666 &

wait $consumer_process_id
