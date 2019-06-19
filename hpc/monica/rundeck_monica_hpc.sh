#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?mount_data? ?num_instance? ?version? ?estimated_time? 
set -eu
[[ $# < 7 ]] && {
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


# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 

#sbatch job name 
SBATCH_JOB_NAME="apsim_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"

NUM_NODES=`expr $NUM_MONICA / 40`
if [ `expr $NUM_MONICA % 40` -ne 0 ] ; then 
  NUM_NODES=`expr $NUM_NODES + 1`
fi

NUM_WORKER=`expr $NUM_MONICA / $NUM_NODES `
if [ `expr $NUM_MONICA % $NUM_NODES` -ne 0 ] ; then 
NUM_WORKER=`expr $NUM_WORKER + 1 `
fi

# start proxy
SINGULARITY_IMAGE=monica-cluster_${VERSION}.sif
LOGOUT=/var/log
MOUNT_LOG=~/log/supervisor/monica/proxy

mkdir -p ~/log/supervisor/monica/proxy


export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_consumer_port=7777
export monica_producer_port=6666
 
export monica_autostart_proxies=true
export monica_autostart_worker=false
export monica_auto_restart_proxies=true
export monica_auto_restart_worker=false

singularity instance start -B $MOUNT_LOG:$LOGOUT ${SINGULARITY_IMAGE} monica_proxy 
singularity run instance://monica_proxy > /dev/null 2>&1 &

# start worker

#sbatch commands
SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} --ntasks=${NUM_NODES} --cpus-per-task=40 -o log/monica-%j"

#sbatch script commands
PROXY_SERVER=`curl ifconfig.me`
SCRIPT_INPUT="${MOUNT_DATA} ${IMAGE_DIR}/${SINGULARITY_IMAGE} ${NUM_WORKER} ${PROXY_SERVER}"


echo "sbatch $SBATCH_COMMANDS batch/sbatch_monica.sh $SCRIPT_INPUT"
