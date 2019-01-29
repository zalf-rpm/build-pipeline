#!/bin/bash

SIMPLACE_SOURCEDIR=$1
SOLUTION_PATH=$2
PROJECT_PATH=$3
VERSION=$4
STARTLINE=$5
ENDLINE=$6
CONTAINER_NAME="simplace_test_run"
OUTPUT_NAME="some_test"

         #-v $WORK_VOLUME:$IMAGE_WORK \
         #-v $OUT_VOLUME:$IMAGE_OUT \
         #-v $DATA_VOLUME:$IMAGE_DATA \
         #-v $FINAL_OUT_VOLUME:$IMAGE_FINAL_OUT \

docker run \
--env SOLUTION=$SOLUTION_PATH \
--env PROJECT=$PROJECT_PATH \
--env LINE_START=$STARTLINE \
--env LINE_END=$ENDLINE \
--env TESTRUN=false \
--env DEBUG=true \
--env FINAL_OUT_NAME=$OUTPUT_NAME \
--mount type=bind,source=$SIMPLACE_SOURCEDIR,target=/simplace/source \
--mount type=bind,source=/simplace_out,target=/simplace/output_final \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace:$VERSION   