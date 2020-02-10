#!/bin/bash -x
#SBATCH --partition=compute

SINGULARITY_IMAGE=$1
MOUNT_LOG=$2
LOGOUT=/var/log

export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_consumer_port=7777
export monica_producer_port=6666
 
export monica_autostart_proxies=true
export monica_autostart_worker=false
export monica_auto_restart_proxies=true
export monica_auto_restart_worker=false

singularity run -B \
$MOUNT_LOG:$LOGOUT \
${SINGULARITY_IMAGE} 
