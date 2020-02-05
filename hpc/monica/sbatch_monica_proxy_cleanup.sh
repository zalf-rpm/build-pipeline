#!/bin/bash -x
#SBATCH --partition=compute
PROXY_NAME=$1
SERVICE_NODE=$2

# this will only work if the current machine can ssh back to the SERVICE_NODE where this singularity instance is running
# if that is not the case, create a ssh key pair and add the public key to the rpm account on the SERVICE_NODE
ssh rpm@$SERVICE_NODE singularity instance stop $PROXY_NAME