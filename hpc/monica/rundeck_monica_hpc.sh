#!/bin/bash -x

SINGULARITY_IMAGE=monica-cluster_2.2.1.168.sif
LOGOUT=/var/log
MOUNT_LOG=~/log


export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_consumer_port=7777
export monica_producer_port=6666
 
export monica_autostart_proxies=true
export monica_autostart_worker=false
export monica_auto_restart_proxies=true
export monica_auto_restart_worker=false

singularity run -B $MOUNT_LOG:$LOGOUT --pwd / ${SINGULARITY_IMAGE} > /dev/null 2>&1 &
