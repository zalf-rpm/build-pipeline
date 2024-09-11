#!/bin/bash -x
#SBATCH --time=00:015:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40


MOUNT_PROJECT=$1
MOUNT_DATA=$2
MOUNT_HOME=$3
PLAYGROUND=$4
MOUNT_DATA_SOURCE1=$5
MOUNT_DATA_SOURCE2=$6
MOUNT_DATA_SOURCE3=$7
READ_ONLY_SOURCES=$8
JWORK=$9
IMAGE_PATH=${10}
VERSION=${11}
DATE=${12}
SCRIPT_NAME=${13}

PROJECT=${JWORK}/project
DATA=${JWORK}/data
USERHOME=${JWORK}/home


# if MOUNT_DATA_SOURCEx is not none, add to MOUNT_DATA_SOURCES
# if read_only_sources is true, mount data sources as read-only
MOUNT_DATA_SOURCES=""
if [ $MOUNT_DATA_SOURCE1 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:${JWORK}/data1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
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
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:$MOUNT_DATA_SOURCE3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
      MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi

# create script start script
START_SCRIPT=${PLAYGROUND}/start_script_${DATE}.sh
cat <<EOF > ${START_SCRIPT}
#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate jupyterenv
python $SCRIPT_NAME
EOF


export SINGULARITYENV_USE_HTTPS=yes
export SINGULARITY_HOME=$PLAYGROUND

singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
-B ${SINGULARITY_HOME}:${SINGULARITY_HOME},\
$MOUNT_PROJECT:$PROJECT,\
$MOUNT_PROJECT:$MOUNT_PROJECT,\
$MOUNT_DATA:$DATA:ro,\
$MOUNT_DATA:$MOUNT_DATA:ro,\
$MOUNT_HOME:$MOUNT_HOME,\
$MOUNT_HOME:$USERHOME${MOUNT_DATA_SOURCES} \
$IMAGE_PATH /bin/bash $START_SCRIPT

rm $START_SCRIPT