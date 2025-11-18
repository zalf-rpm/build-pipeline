#!/bin/bash -x

SINGULARITY_IMAGE=$1
MOUNT_LOG=$2
CONSUMER_PORT=$3
PRODUCER_PORT=$4
INTERN_PROXY_IN_PORT=$5
INTERN_PROXY_OUT_PORT=$6

SHARED_ID=${7:-"false"} # optional
LOGOUT=/var/log

SHARED_ID_MODE=-pps
if [ "$SHARED_ID" == "true" ]; then
    SHARED_ID_MODE=-prs
fi
ENV_VARS=monica_intern_in_port=${INTERN_PROXY_IN_PORT},\
monica_intern_out_port=${INTERN_PROXY_OUT_PORT},\
monica_consumer_port=${CONSUMER_PORT},\
monica_producer_port=${PRODUCER_PORT},\
monica_autostart_proxies=true,\
monica_autostart_worker=false,\
monica_auto_restart_proxies=true,\
monica_auto_restart_worker=false,\
monica_proxy_out_mode=${SHARED_ID_MODE}

singularity run --env ${ENV_VARS} -B \
$MOUNT_LOG:$LOGOUT \
${SINGULARITY_IMAGE} 
