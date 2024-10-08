#!/bin/bash 
#SBATCH --time=00:015:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40

USER=$1
LOGIN_HOST=$2
MOUNT_PROJECT=$3
MOUNT_DATA=$4
MOUNT_HOME=$5
PLAYGROUND=$6
MOUNT_DATA_SOURCE1=$7
MOUNT_DATA_SOURCE2=$8
MOUNT_DATA_SOURCE3=$9
JWORK=${10}
IMAGE_PATH=${11}
VERSION=${12}

PROJECT=${JWORK}/project
DATA=${JWORK}/data
USERHOME=${JWORK}/home

cd ${PLAYGROUND}
cp -f /beegfs/common/batch/startjupyter_${VERSION}.sh .
STATUS=$?
if [ $STATUS != 0 ]; then                   
   echo "Copy startjupyter_${VERSION}.sh: $STATUS - failed" 
   exit 1
fi

# if MOUNT_DATA_SOURCEx is not none, add to MOUNT_DATA_SOURCES
# if read_only_sources is true, mount data sources as read-only
MOUNT_DATA_SOURCES=""
if [ $MOUNT_DATA_SOURCE1 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:${JWORK}/data1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE2 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE2:${JWORK}/data2"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE3 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:${JWORK}/data3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi

export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITY_HOME=$PLAYGROUND

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
--nv \
-B ${SINGULARITY_HOME}:${SINGULARITY_HOME},$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_HOME:$USERHOME${MOUNT_DATA_SOURCES} \
$IMAGE_PATH /bin/bash startjupyter_${VERSION}.sh $PLAYGROUND

printf 'jupyter exited' 1>&2