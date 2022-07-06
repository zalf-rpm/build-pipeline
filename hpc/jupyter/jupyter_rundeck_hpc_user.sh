#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?mount_climate_data? ?mount_project_data? ?estimated_time? ?partition? ?version?
set -eu
[[ $# < 8 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
LOGIN_HOST=$3
MOUNT_DATA=$4
MOUNT_PROJECT=$5
TIME=$6
PARTITION=$7
VERSION=$8

#sbatch job name 
SBATCH_JOB_NAME="jupyter_${JOB_EXEC_ID}"

# get jupyter as prepared docker image
IMAGE_DIR=/beegfs/common/singularity/jupyter
SINGULARITY_IMAGE=${VERSION}.sif
IMAGE_JUPYTER_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_JUPYTER_PATH} ] ; then
echo "File '${IMAGE_JUPYTER_PATH}' not found"
fi

WORKDIR=~
LOGS=$WORKDIR/log
mkdir -p $LOGS

HPC_PARTITION="--partition=compute"
CORES=80
echo "warning..."
if [ $PARTITION == "highmem" ] ; then 
  HPC_PARTITION="--partition=highmem"
  CORES=80
elif [ $PARTITION == "gpu" ] ; then 
  HPC_PARTITION="--partition=gpu"
  CORES=48
elif [ $PARTITION == "fat" ] ; then 
  HPC_PARTITION="--partition=fat"
  CORES=160
fi

if  [[ $MOUNT_PROJECT == *"<username>"* ]] ; then
  MOUNT_PROJECT=$(echo $MOUNT_PROJECT | sed "s/<username>/${USER}/")
fi 

# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c ${CORES} -o ${LOGS}/jupyter_notebook_${USER}_%j.log"
SCRIPT_INPUT="${USER} ${LOGIN_HOST} ${MOUNT_PROJECT} ${MOUNT_DATA} ${WORKDIR} ${IMAGE_JUPYTER_PATH}"

echo $CMD_LINE_SLURM
echo $SCRIPT_INPUT
cd ${WORKDIR}
BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/jupyter-notebook-server_${VERSION}.sh $SCRIPT_INPUT )

LOG_NAME=${LOGS}/jupyter_notebook_${USER}_${BATCHID}.log
COUNTER=0
while [ ! -f ${LOG_NAME} ] && [ ! $COUNTER -eq 30 ] ; do 
sleep 10
COUNTER=$(($COUNTER + 1))
if [ $COUNTER == 30 ] ; then
    scancel $BATCHID
    echo "timeout: no free slot available. Try again later"
fi 
done
sleep 5
if [ -f ${LOG_NAME} ] ; then
    #cat ${LOG_NAME}
PORT=8888
NODEHOST=$(squeue -j ${BATCHID} --noheader --format="%R" )
cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8888:${NODEHOST}:${PORT} ${USER}@${LOGIN_HOST}

2. login at http://localhost:8888/lab with your password
  
  For initial login, please find the token in your log file at:
   ${LOG_NAME}

   Find line: 
   "To access the server, open this file in a browser"
    Extract token from URL
    http://127.0.0.1:8888/lab?token=<some_token>

  Open Browser
   http://localhost:8888/
  This will open a page to set a password using that token.

   Please choose a different password from Zalf password!

   KEEP YOUR TOKEN AND PASSWORD SECRET!
END

fi 

