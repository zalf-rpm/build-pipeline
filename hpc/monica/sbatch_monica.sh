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

ENV_VARS=monica_instances=$NUM_WORKER,\
monica_intern_in_port=${INTERN_IN_PORT},\
monica_intern_out_port=${INTERN_OUT_PORT},\
monica_autostart_proxies=false,\
monica_autostart_worker=true,\
monica_auto_restart_proxies=false,\
monica_auto_restart_worker=true,\
monica_proxy_in_host=$PROXY_SERVER,\
monica_proxy_out_host=$PROXY_SERVER

srun singularity run --env ${ENV_VARS} -B \
$MOUNT_DATA:$DATADIR,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE} 
