#!/bin/bash -x
#SBATCH --partition=compute
PROXY_NAME=$1
SERVICE_NODE=$2

ssh rpm@$SERVICE_NODE singularity instance stop $PROXY_NAME