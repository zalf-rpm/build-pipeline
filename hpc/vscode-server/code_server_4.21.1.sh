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
PASSW=${10}
READ_ONLY_SOURCES=${11}

# fail if no password is given
if [ -z "$PASSW" ] ; then
    echo "No password given"
    exit 1
fi
# generate hashed password
# PYTHONIMG=/beegfs/common/singularity/jupyter/scipy-notebook_lab-3.4.2.sif
# HASH=$(singularity exec $PYTHONIMG python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('$PASSW','sha1'))\")")
HASHIMG=/beegfs/common/singularity/code_server/hash_1.0.sif
HASH=$(singularity exec $HASHIMG printf "$PASSW" | sha256sum | cut -d' ' -f1)

mkdir -p ${HOMEDIR}/.config/code-server/
# create config.yaml
if [ ! -f ${HOMEDIR}/.config/code-server/config.yaml ] ; then

cat <<EOF > ${HOMEDIR}/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8443
auth: password
hashed-password: $HASH
cert: false
EOF
elif [ ! -z "$PASSW" ] ; then
# update password
sed -i "s/hashed-password: .*/hashed-password: $HASH/g" ${HOMEDIR}/.config/code-server/config.yaml
fi 

PROJECT=/project
DATA=/data
CLUSTERHOME=/myhome
MOUNT_CLUSTERHOME=/home/$SCRIPT_USER
CONFIG=/config
MOUNT_CONFIG=$HOMEDIR/.config
mkdir -p $MOUNT_CONFIG

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

1. Exit the Code Session ("File" -> "Exit" in the menu of the Code Server window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

singularity exec --cleanenv \
-B $MOUNT_CONFIG:$CONFIG,$MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_CLUSTERHOME:${CLUSTERHOME}${MOUNT_DATA_SOURCES} \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
/app/code-server/bin/code-server 
printf 'code sever exited' 1>&2