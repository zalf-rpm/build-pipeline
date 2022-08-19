#!/bin/bash -x

MOUNT_DATA=$1
SINGULARITY_IMAGE=$2
NUM_WORKER=$3
PROXY_SERVER=$4
MOUNT_LOG=$5

DATADIR=/monica_data/climate-data
LOGOUT=/var/log

ENV_VARS=monica_instances=$NUM_WORKER,\
monica_intern_in_port=6677,\
monica_intern_out_port=7788,\
monica_autostart_proxies=false,\
monica_autostart_worker=true,\
monica_auto_restart_proxies=false,\
monica_auto_restart_worker=true,\
monica_proxy_in_host=$PROXY_SERVER,\
monica_proxy_out_host=$PROXY_SERVER

singularity run --env ${ENV_VARS} -B \
$MOUNT_DATA:$DATADIR:ro,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE} 
