#!/bin/bash -x

SINGULARITY_IMAGE=monica-cluster_2.2.1.170.sif
LOGOUT=/var/log
MOUNT_LOG=~/log/supervisor/monica/proxy

mkdir -p ~/log/supervisor/monica/proxy

ENV_VARS=monica_intern_in_port=6677,\
monica_intern_out_port=7788,\
monica_consumer_port=7777,\
monica_producer_port=6666,\
monica_autostart_proxies=true,\
monica_autostart_worker=false,\
monica_auto_restart_proxies=true,\
monica_auto_restart_worker=false

singularity instance start -B $MOUNT_LOG:$LOGOUT ${SINGULARITY_IMAGE} monica_proxy 
singularity run --env ${ENV_VARS} instance://monica_proxy > /dev/null 2>&1 &
