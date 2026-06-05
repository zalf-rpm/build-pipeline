#!/bin/bash +x

# this will run as sbatch script
# resources will be passed by command line

MOUNT_PROJECT=$1
MOUNT_DATA=$2
MOUNT_HOME=$3
PLAYGROUND=$4
MOUNT_DATA_SOURCE1=$5
MOUNT_DATA_SOURCE2=$6
MOUNT_DATA_SOURCE3=$7
JWORK=$8
IMAGE_PATH=$9
VERSION=${10}
READ_ONLY_SOURCES=${11}
GFX_SUPPORT=${12}
LOCAL_PORT=${13} # local host port for ssh tunnel, e.g. 8888 on user workstation
LOGIN_HOST=${14} # login host for ssh tunnel, e.g. login.hpc.cluster.de


# get current job id from environment variable
JOBID=$SLURM_JOB_ID
# get current node name from environment variable
NODE=$(hostname)

PROJECT=${JWORK}/project
DATA=${JWORK}/data
USERHOME=${JWORK}/home

# copy the start script to playground, so it can be executed inside container, and check if copy was successful
cd ${PLAYGROUND}
cp -f /beegfs/common/batch/ro_startjupyter_${VERSION}.sh .
STATUS=$?
if [ $STATUS != 0 ]; then                   
   echo "Copy ro_startjupyter_${VERSION}.sh: $STATUS - failed" 
   exit 1
fi

# allocate free port on node for jupyter lab
JUPYTER_PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
# check if free port was found
if [ -z "$JUPYTER_PORT" ] ; then
   echo "Error: Could not assign free port on node for jupyter lab" >&2
   exit 1
fi
echo "Free port on allocated node: $JUPYTER_PORT"

# if MOUNT_DATA_SOURCEx is not none, add to MOUNT_DATA_SOURCES
# if read_only_sources is true, mount data sources as read-only
MOUNT_DATA_SOURCES=""
if [ $MOUNT_DATA_SOURCE1 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:${JWORK}/data1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
  # also mount data source to same path inside container for compatibility 
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:$MOUNT_DATA_SOURCE1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE2 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE2:${JWORK}/data2"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
  # also mount data source to same path inside container for compatibility
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE2:$MOUNT_DATA_SOURCE2"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE3 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:${JWORK}/data3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
  # also mount data source to same path inside container for compatibility
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:$MOUNT_DATA_SOURCE3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi

# if gfx support is true, add --nv flag to singularity command, to use gpu inside container
GFX=""
if [ "$GFX_SUPPORT" == "true" ] ; then
  GFX="--nv"
fi

# generate launch instructions for the user

LAUNCH_FOLDER=/beegfs/${USER}/jupyter_playground${VERSION}/.launch_instructions
mkdir -p -m 700 $LAUNCH_FOLDER
LAUNCH_FILE=${LAUNCH_FOLDER}/${JOBID}.rundeck

# clear launch folder of old files
rm -f ${LAUNCH_FOLDER}/*.rundeck

cat <<EOF > ${LAUNCH_FILE}

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${LOCAL_PORT}:${NODE}:${JUPYTER_PORT} ${USER}@${LOGIN_HOST}

2. open in your web browser:
   
   http://localhost:${LOCAL_PORT}/lab 

3. please shutdown your jupyter after finishing your work with
   
   'File->Shut Down' in the jupyterlab menu
    or end the SLURM job with
   scancel ${JOBID}
    
EOF


export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITY_HOME=$PLAYGROUND

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv $GFX \
-B ${SINGULARITY_HOME}:${SINGULARITY_HOME},$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_HOME:$USERHOME${MOUNT_DATA_SOURCES} \
$IMAGE_PATH /bin/bash ro_startjupyter_${VERSION}.sh $PLAYGROUND $JUPYTER_PORT

printf 'jupyter exited' 1>&2

scancel $JOBID