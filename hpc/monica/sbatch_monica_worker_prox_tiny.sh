#!/bin/bash -x

MOUNT_DATA=$1
SINGULARITY_IMAGE=$2
NUM_WORKER=$3
MOUNT_LOG=$4

DATADIR=/monica_data/climate-data
LOGOUT=/var/log

# start proxy and worker on the same node
ENV_VARS=monica_intern_in_port=6677,\
monica_intern_out_port=7788,\
monica_consumer_port=7777,\
monica_producer_port=6666,\
monica_autostart_proxies=true,\
monica_auto_restart_proxies=true,\
monica_instances=$NUM_WORKER,\
monica_autostart_worker=true,\
monica_auto_restart_worker=true,\
monica_proxy_in_host=localhost,\
monica_proxy_out_host=localhost

singularity run --env ${ENV_VARS} -B \
$MOUNT_DATA:$DATADIR:ro,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE}
