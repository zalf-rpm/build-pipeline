#!/bin/bash -x
#SBATCH --cpus-per-task=40

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
PYTHON_SCRIPT=${12}
SBATCH_JOB_NAME=${13}
shift 13
SCRIPT_PARAMETERS=$@

echo "SLURM NODES" ${SLURM_JOB_NODELIST}

NODE_LIST=$( ./batch/SplitSlurmNodes ${SLURM_JOB_NODELIST} )

IFS=',' read -ra ADDR <<< "${NODE_LIST}"
IFS=' '

NODE_PYTHON_SCRIPT=${ADDR[0]}
NODE_PROXY=${ADDR[1]}
NODE_ARRAY_WORKER=("${ADDR[@]:3}")

echo "worker array: " $NODE_ARRAY_WORKER
DATE=`date +%Y-%d-%B_%H%M%S`

# start proxy
mkdir -p $MOUNT_LOG_PROXY
srun --exclusive -w $NODE_PROXY -N1 -n1 -o ${MONICA_LOG}/monica_proxy_%j batch/sbatch_monica_proxy.sh ${SINGULARITY_MONICA_IMAGE} $MOUNT_LOG_PROXY &


# start worker
mkdir -p $MOUNT_LOG_WORKER
for node in "${NODE_ARRAY_WORKER[@]}"; do
    echo "worker: " ${node}
    srun --exclusive -w ${node} -N1 -n1 -c40 -o ${MONICA_LOG}/monica_worker_${node}_%j batch/sbatch_monica_worker.sh $MOUNT_DATA_CLIMATE $SINGULARITY_MONICA_IMAGE $NUM_WORKER "${NODE_PROXY}.opa" $MOUNT_LOG_WORKER &
done

MONICA_PARAMS=$MONICA_WORKDIR/monica-parameters

PATH_TO_PYTHON_SCRIPT="${PYTHON_SCRIPT%/*}"
FILENAME_PYTHON_SCRIPT="${PYTHON_SCRIPT##*/}"

# start producer
srun --exclusive -w ${NODE_PYTHON_SCRIPT} -N1 -n1 -o ${MONICA_LOG}/monica_proj_plog-%j -e ${MONICA_LOG}/monica_proj_eplog-%j batch/sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $MONICA_PARAMS $MONICA_WORKDIR/$PATH_TO_PYTHON_SCRIPT $FILENAME_PYTHON_SCRIPT server=$NODE_PROXY prod-server-port=6666 cons-server-port=7777 $SCRIPT_PARAMETERS &
