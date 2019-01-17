#!/bin/bash

SVN_PATH=$1
SVN_USER=$2
SVN_PASS=$3
SOLUTION_PATH=$4
PROJECT_PATH=$5
VERSION=$6
STARTLINE=$7
ENDLINE=$8
CONTAINER_NAME="simplace_test_run"

         #-v $WORK_VOLUME:$IMAGE_WORK \
         #-v $OUT_VOLUME:$IMAGE_OUT \
         #-v $DATA_VOLUME:$IMAGE_DATA \
         #-v $FINAL_OUT_VOLUME:$IMAGE_FINAL_OUT \

docker run \
--env SVN_CHECKOUT_PATH=$SVN_PATH \
--env SVN_USER=$SVN_USER \
--env SVN_PASSWORD=$SVN_PASS \
--env SOLUTION=$SOLUTION_PATH \
--env PROJECT=$PROJECT_PATH \
--env LINE_START=$STARTLINE \
--env LINE_END=$ENDLINE \
--env TESTRUN=false \
--env DEBUG=true \
--mount type=bind,source=/simplace_out,target=/simplace/output_final \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace:$VERSION   