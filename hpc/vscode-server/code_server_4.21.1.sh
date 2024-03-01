#!/bin/sh -x
#SBATCH --time=08:00:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --output=/home/%u/code-server.job.%j

# code_server from https://github.com/linuxserver/docker-code-server

SCRIPT_USER=$1
LOGIN_HOST_NAME=$2
MOUNT_PROJECT=$3
MOUNT_DATA=$4
HOMEDIR=$5
SINGULARITY_IMAGE=$6
MOUNT_DATA_SOURCE1=$7
MOUNT_DATA_SOURCE2=$8
MOUNT_DATA_SOURCE3=$9
READ_ONLY_SOURCES=${10}
VERSION=${11}

PROJECT=$MOUNT_PROJECT
DATA=$MOUNT_DATA
CLUSTERHOME=/home/$SCRIPT_USER
MOUNT_CLUSTERHOME=/home/$SCRIPT_USER
CONFIG=/config
MOUNT_CONFIG=$HOMEDIR/.config
mkdir -p $MOUNT_CONFIG

EXTENSIONS=/extensions
MOUNT_EXT=/beegfs/common/singularity/code_server/extensions/v${VERSION}


# if MOUNT_DATA_SOURCEx is not none, add to MOUNT_DATA_SOURCES
# if read_only_sources is true, mount data sources as read-only
MOUNT_DATA_SOURCES=""
if [ $MOUNT_DATA_SOURCE1 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:$MOUNT_DATA_SOURCE1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE2 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE2:$MOUNT_DATA_SOURCE2"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE3 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:$MOUNT_DATA_SOURCE3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi


export SINGULARITY_HOME=${HOMEDIR}

cd ${HOMEDIR}

export SINGULARITYENV_DEFAULT_WORKSPACE=${HOMEDIR}
export SINGULARITYENV_TZ=Etc/UTC
#export SINGULARITYENV_PASSWORD=$PASSW
export SINGULARITYENV_USER=$(id -un)

cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8443:${HOSTNAME}:8443 ${SCRIPT_USER}@${LOGIN_HOST_NAME}

   and point your web browser to http://localhost:8443

2. log in to Code Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: your selected password 
When done using Code Server, terminate the job by:

1. Exit the Code Session ("File" -> "Sign out of Code-Server" in the menu of the Code Server window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

singularity exec --cleanenv \
-B $MOUNT_EXT:$EXTENSIONS,$MOUNT_CONFIG:$CONFIG,$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_CLUSTERHOME:${CLUSTERHOME}${MOUNT_DATA_SOURCES} \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
/app/code-server/bin/code-server > $HOMEDIR/log/code-server.log
printf 'code sever exited' 1>&2