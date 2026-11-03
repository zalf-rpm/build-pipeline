#!/bin/bash 

# script input
PROJECT_DIR=$1
MOUNT_DATA_SOURCE1=$2 # optional, readonly
MOUNT_DATA_SOURCE2=$3 # optional, readonly
MOUNT_DATA_SOURCE3=$4 # optional, readonly
MOUNT_OUTPUT=$5 # optional, readonly
IMAGE_PATH=$6
LOGIN_HOST=$7
LAUNCH_DIR=$8

# check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory $PROJECT_DIR does not exist. Exiting."
    exit 1
fi
# mount the project directory as read-write
MOUNTS="$PROJECT_DIR:rw"

# add optional folders
if [ "$MOUNT_DATA_SOURCE1" = "none" ]; then
    echo "No data directory provided, skipping mount."
else
    #check if data directory exists
    if [ ! -d "$MOUNT_DATA_SOURCE1" ]; then
        echo "Data directory $MOUNT_DATA_SOURCE1 does not exist. Exiting."
        exit 1
    fi
    MOUNTS="$MOUNTS,$MOUNT_DATA_SOURCE1:$MOUNT_DATA_SOURCE1:ro"
fi
if [ "$MOUNT_DATA_SOURCE2" = "none" ]; then
    echo "No data directory provided, skipping mount."
else
    #check if data directory exists
    if [ ! -d "$MOUNT_DATA_SOURCE2" ]; then
        echo "Data directory $MOUNT_DATA_SOURCE2 does not exist. Exiting."
        exit 1
    fi
    MOUNTS="$MOUNTS,$MOUNT_DATA_SOURCE2:$MOUNT_DATA_SOURCE2:ro"
fi
if [ "$MOUNT_DATA_SOURCE3" = "none" ]; then
    echo "No data directory provided, skipping mount."
else
    #check if data directory exists
    if [ ! -d "$MOUNT_DATA_SOURCE3" ]; then
        echo "Data directory $MOUNT_DATA_SOURCE3 does not exist. Exiting."
        exit 1
    fi
    MOUNTS="$MOUNTS,$MOUNT_DATA_SOURCE3:$MOUNT_DATA_SOURCE3:ro"
fi
if [ "$MOUNT_OUTPUT" = "none" ]; then
    echo "No output data directory provided, skipping mount."
else
    #check if output data directory exists
    if [ ! -d "$MOUNT_OUTPUT" ]; then
        # check if it can be created
        mkdir -p "$MOUNT_OUTPUT" || { echo "Output data directory $MOUNT_OUTPUT does not exist and cannot be created. Exiting."; exit 1; }
    fi
    MOUNTS="$MOUNTS,$MOUNT_OUTPUT:rw"
fi

NV=""
if [ "$SLURM_JOB_PARTITION" = "gpu" ]; then
    NV="--nv"
fi

HOMEDIR=/beegfs/$USER/ide
mkdir -p $HOMEDIR
# make ssh folder
SSH_FOLDER=$HOMEDIR/.ssh
mkdir -p $SSH_FOLDER
# make sure the directory can only be accessed by the user
chmod 700 $SSH_FOLDER
chmod 700 $HOMEDIR

# create empty authorized_keys file if it doesn't exist
touch $SSH_FOLDER/authorized_keys

# workdir that is cleaned up after the session
DATE=`date +%Y-%d-%B_%H%M%S`
WORKDIR=/scratch/${USER}_ide-temp_$DATE
mkdir -p $WORKDIR
# function to clean up work directory on exit
cleanup() {
    rm -rf $WORKDIR
    echo "Workdir directory removed."
  fi
}   
# trap EXIT signal to ensure cleanup is called on job completion
trap cleanup EXIT

# get a free port
# allocate free port on node for ssh
CONTAINER_SSH_PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
# check if free port was found
if [ -z "$CONTAINER_SSH_PORT" ] ; then
   echo "Error: Could not assign free port on node for container" >&2
   exit 1
fi
echo "Free port on allocated node: $CONTAINER_SSH_PORT"

# write instructions to launch file
LAUNCH_FILE=$LAUNCH_DIR/${SLURM_JOB_ID}.rundeck
cat <<EOF > ${LAUNCH_FILE}

1. SSH tunnel from your workstation using the following command:

    TBD

3. please shutdown your container after finishing your work with
   end the SLURM job with
   scancel ${JOBID}
    
EOF

# todo:
# user_sshd_config 
# hostkey

# user has to add their public key to the authorized_keys file in the ide-home directory for ssh access
export SINGULARITY_HOME=${HOMEDIR}
export SINGULARITY_BINDPATH="${WORKDIR}/run:/run,${WORKDIR}/tmp:/tmp,$MOUNTS "

cd ${PROJECT_DIR}
singularity exec $NV --containall --no-home \
    -H ${HOMEDIR} \
    -W ${PROJECT_DIR} \
    $IMAGE_PATH \
    /usr/sbin/sshd -D -p $CONTAINER_SSH_PORT -f user_sshd_config -h hostkey

printf 'container exited' 1>&2
