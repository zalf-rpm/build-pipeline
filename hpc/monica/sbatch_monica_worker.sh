#!/bin/bash -x

MOUNT_DATA=$1
SINGULARITY_IMAGE=$2
NUM_WORKER=$3
PROXY_SERVER=$4
MOUNT_LOG=$5

DATADIR=/monica_data/climate-data
LOGOUT=/var/log

export monica_instances=$NUM_WORKER
export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_autostart_proxies=false
export monica_autostart_worker=true
export monica_auto_restart_proxies=false
export monica_auto_restart_worker=true
export monica_proxy_in_host=$PROXY_SERVER
export monica_proxy_out_host=$PROXY_SERVER

singularity run -B \
$MOUNT_DATA:$DATADIR,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE} 
