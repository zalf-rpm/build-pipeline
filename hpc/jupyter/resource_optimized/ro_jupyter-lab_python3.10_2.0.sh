#!/bin/bash 
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
JUPYTER_PORT=${11}
READ_ONLY_SOURCES=${12}
GFX_SUPPORT=${13} # not supported in this image, but passed for compatibility with other versions

PROJECT=${JWORK}/project
DATA=${JWORK}/data
USERHOME=${JWORK}/home

cd ${PLAYGROUND}
cp -f /beegfs/common/batch/ro_startjupyter_${VERSION}.sh .
STATUS=$?
if [ $STATUS != 0 ]; then                   
   echo "Copy ro_startjupyter_${VERSION}.sh: $STATUS - failed" 
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

export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITY_HOME=$PLAYGROUND

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
-B ${SINGULARITY_HOME}:${SINGULARITY_HOME},$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_HOME:$USERHOME${MOUNT_DATA_SOURCES} \
$IMAGE_PATH /bin/bash ro_startjupyter_${VERSION}.sh $PLAYGROUND $JUPYTER_PORT

printf 'jupyter exited' 1>&2