#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_data? ?num_instance? ?version? ?estimated_time? ?hostname?
set -eu
[[ $# < 8 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
MOUNT_DATA=$4
NUM_MONICA=$5
VERSION=$6
TIME=$7
HOSTNAME=$8

MONICA_PER_NODE=40

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="monica_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

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

# start proxy
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
LOGOUT=/var/log
MOUNT_LOG=~/log/supervisor/monica/proxy
mkdir -p $MOUNT_LOG


export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_consumer_port=7777
export monica_producer_port=6666
 
export monica_autostart_proxies=true
export monica_autostart_worker=false
export monica_auto_restart_proxies=true
export monica_auto_restart_worker=false

echo "singularity instance start -B $MOUNT_LOG:$LOGOUT ${SINGULARITY_IMAGE} monica_proxy "
echo "singularity run instance://monica_proxy > /dev/null 2>&1 &"

# start worker

#sbatch commands
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --ntasks=${NUM_NODES} --cpus-per-task=40 -o log/monica-%j"

#sbatch script commands
PROXY_SERVER=$HOSTNAME
SCRIPT_INPUT="${MOUNT_DATA} ${IMAGE_PATH} ${NUM_WORKER} ${PROXY_SERVER}"


echo "sbatch $SBATCH_COMMANDS batch/sbatch_monica.sh $SCRIPT_INPUT"
