#!/bin/bash -x

MOUNT_DATA=$1
SINGULARITY_IMAGE=$2
NUM_WORKER=$3
PROXY_SERVER=$4
INTERN_IN_PORT=$5
INTERN_OUT_PORT=$6

DATADIR=/monica_data/climate-data
LOGOUT=/var/log
MOUNT_LOG=~/log/supervisor/monica/worker
mkdir -p $MOUNT_LOG

export monica_instances=$NUM_WORKER
export monica_intern_in_port=${INTERN_IN_PORT}
export monica_intern_out_port=${INTERN_OUT_PORT}
export monica_autostart_proxies=false
export monica_autostart_worker=true
export monica_auto_restart_proxies=false
export monica_auto_restart_worker=true
export monica_proxy_in_host=$PROXY_SERVER
export monica_proxy_out_host=$PROXY_SERVER

srun singularity run -B \
$MOUNT_DATA:$DATADIR,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE} 
