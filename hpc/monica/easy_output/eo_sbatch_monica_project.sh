#!/bin/bash -x

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
TMP_DIR=${12}
CONSUMER=${13}
PRODUCER=${14}
RUN_SETUPS=${15}
SETUPS_FILE=${16}
CLEANUP=${17}
ADDITIONAL_PARAMS="${@:18}"

# function to clean up work directory on exit
cleanup() {
  if [ "$CLEANUP" = "true" ]; then
    echo "Cleaning up workdir directory: $MONICA_WORKDIR"
    rm -rf $MONICA_WORKDIR
    echo "Workdir directory removed."
  fi
}   
# trap EXIT signal to ensure cleanup is called on job completion
trap cleanup EXIT

# resources (1 monica proxy)+(1 producer)+(1 consumer)+(n monica worker)

NODE_PROXY=$(srun --het-group=0 hostname)
CONSUMER_PORT=7777
PRODUCER_PORT=6666
INTERN_PROXY_IN_PORT=6677
INTERN_PROXY_OUT_PORT=7788


#$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
# get free ports for proxy, consumer, producer on the proxy node
FREE_PORTS=$(srun --het-group=0 python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' && \
              srun --het-group=0 python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' && \
              srun --het-group=0 python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' && \
              srun --het-group=0 python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' )
CONSUMER_PORT=$(echo $FREE_PORTS | awk '{print $1}')
PRODUCER_PORT=$(echo $FREE_PORTS | awk '{print $2}')
INTERN_PROXY_IN_PORT=$(echo $FREE_PORTS | awk '{print $3}')
INTERN_PROXY_OUT_PORT=$(echo $FREE_PORTS | awk '{print $4}')

# check if the ports were assigned
if [ -z "$CONSUMER_PORT" ] || [ -z "$PRODUCER_PORT" ] || [ -z "$INTERN_PROXY_IN_PORT" ] || [ -z "$INTERN_PROXY_OUT_PORT" ] ; then
  echo "Error: Could not assign free ports on node $NODE_PROXY" >&2
  exit 1
fi


# start proxy
mkdir -p $MOUNT_LOG_PROXY
srun --het-group=0 -o ${MONICA_LOG}/monica_proxy_%j batch/eo_sbatch_monica_proxy.sh ${SINGULARITY_MONICA_IMAGE} $MOUNT_LOG_PROXY $CONSUMER_PORT $PRODUCER_PORT $INTERN_PROXY_IN_PORT $INTERN_PROXY_OUT_PORT $TMP_DIR &

# start worker
mkdir -p $MOUNT_LOG_WORKER
srun --het-group=3 -o ${MONICA_LOG}/monica_worker_%j batch/eo_sbatch_monica_worker.sh $MOUNT_DATA_CLIMATE $SINGULARITY_MONICA_IMAGE $NUM_WORKER "${NODE_PROXY}.opa" $MOUNT_LOG_WORKER $INTERN_PROXY_IN_PORT $INTERN_PROXY_OUT_PORT $TMP_DIR &

RESOURCE_CHECKOUT=/beegfs/rpm/projects/monica/resource
MONICA_PARAMS=$RESOURCE_CHECKOUT/monica-parameters
MAS_INFRASTRUCTURE=$RESOURCE_CHECKOUT/mas-infrastructure

# check if CONSUMER has a path or is just a filename
if [[ "$CONSUMER" == */* ]]; then
    # CONSUMER has a path
    PATH_TO_CONSUMER="${CONSUMER%/*}"
    FILENAME_CONSUMER="${CONSUMER##*/}"
    MOUNT_CONSUMER=$MONICA_WORKDIR/$PATH_TO_CONSUMER
else
    # CONSUMER is just a filename, use the default path
    FILENAME_CONSUMER="$CONSUMER"
    MOUNT_CONSUMER=$MONICA_WORKDIR
fi

# start consumer
srun --het-group=1 -o ${MONICA_LOG}/monica_proj_clog-%j -e ${MONICA_LOG}/monica_proj_eclog-%j batch/eo_sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $TMP_DIR $MONICA_PARAMS $MAS_INFRASTRUCTURE $MOUNT_CONSUMER $FILENAME_CONSUMER mode=remoteConsumer-remoteMonica server=$NODE_PROXY.opa port=$CONSUMER_PORT &
consumer_process_id=$!

# check if PRODUCER has a path or is just a filename
if [[ "$PRODUCER" == */* ]]; then
    # PRODUCER has a path
    PATH_TO_PRODUCER="${PRODUCER%/*}"
    FILENAME_PRODUCER="${PRODUCER##*/}"
    MOUNT_PRODUCER=$MONICA_WORKDIR/$PATH_TO_PRODUCER
else
    # PRODUCER is just a filename, use the default path
    FILENAME_PRODUCER="$PRODUCER"
    MOUNT_PRODUCER=$MONICA_WORKDIR
fi

# start producer
srun --het-group=2 -o ${MONICA_LOG}/monica_proj_plog-%j -e ${MONICA_LOG}/monica_proj_eplog-%j batch/eo_sbatch_monica_python.sh $SINGULARITY_PYTHON_IMAGE $MOUNT_DATA_CLIMATE $MOUNT_DATA_PROJECT $MONICA_OUT $TMP_DIR $MONICA_PARAMS $MAS_INFRASTRUCTURE $MOUNT_PRODUCER $FILENAME_PRODUCER mode=remoteProducer-remoteMonica server=$NODE_PROXY.opa server-port=$PRODUCER_PORT  run-setups=$RUN_SETUPS setups-file=$SETUPS_FILE $ADDITIONAL_PARAMS &
wait $consumer_process_id

