#!/bin/bash -x

SINGULARITY_IMAGE=$1
MOUNT_LOG=$2
SHARED_ID=${3: "false"} # optional
LOGOUT=/var/log

SHARED_ID_MODE=-pps
if [ "$SHARED_ID" == "true" ]; then
    SHARED_ID_MODE=-prs
fi
ENV_VARS=monica_intern_in_port=6677,\
monica_intern_out_port=7788,\
monica_consumer_port=7777,\
monica_producer_port=6666,\
monica_autostart_proxies=true,\
monica_autostart_worker=false,\
monica_auto_restart_proxies=true,\
monica_auto_restart_worker=false,\
monica_proxy_out_mode=${SHARED_ID_MODE}

singularity run --env ${ENV_VARS} -B \
$MOUNT_LOG:$LOGOUT \
${SINGULARITY_IMAGE} 
