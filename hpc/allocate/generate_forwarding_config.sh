#!/bin/bash -x

USER=$1
PARTITION=${2,-"all"}
CONFIG_FILE=${3,-"config_generated"}
KEY_PATH=${4,-"C:/Users/$USER/.ssh/id_rsa_openssh"}
HOST_NAME=${5,-"example.cluster.de:22"}


NODES=125
GPU_NODES=5
FAT_NODES=2

if [ -z "$USER" ]; then
    echo "Username is not set. Please run this script as a user."
    exit
fi

# if compute nodes are requested or all nodes are requested
if [ "$PARTITION" == "compute" ] || [ "$PARTITION" == "all" ]; then

for i in $(seq 1 $NODES); do
NODE="node$(printf "%03d" $i)"
TEXT="Host $NODE
    HostName $NODE.service
    User $USER
    IdentityFile $KEY_PATH
    ProxyJump $USER@$HOST_NAME"
    echo "$TEXT" >> $CONFIG_FILE
done
fi

# if gpu nodes are requested or all nodes are requested
if [ "$PARTITION" == "gpu" ] || [ "$PARTITION" == "all" ]; then
for i in $(seq 1 $GPU_NODES); do
NODE="gpu$(printf "%03d" $i)"
TEXT="Host $NODE
    HostName $NODE.service
    User $USER
    IdentityFile $KEY_PATH
    ProxyJump $USER@$HOST_NAME"
    echo "$TEXT" >> $CONFIG_FILE
done
fi

# if fat nodes are requested or all nodes are requested
if [ "$PARTITION" == "fat" ] || [ "$PARTITION" == "all" ]; then
for i in $(seq 1 $FAT_NODES); do
NODE="fat$(printf "%03d" $i)"
TEXT="Host $NODE
    HostName $NODE.service
    User $USER
    IdentityFile $KEY_PATH
    ProxyJump $USER@$HOST_NAME"
    echo "$TEXT" >> $CONFIG_FILE
done
fi

