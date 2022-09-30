#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?estimated_time? ?partition? ?version?
set -eu
[[ $# < 6 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
LOGIN_HOST=$3
TIME=$4
PARTITION=$5
VERSION=$6

MOUNT_DATA=/beegfs/common/data
MOUNT_PROJECT=/beegfs/$USER/
MOUNT_HOME=/home/$USER

#sbatch job name 
SBATCH_JOB_NAME="jupyter_${JOB_EXEC_ID}"

# get jupyter as prepared docker image
IMAGE_DIR=/beegfs/common/singularity/python
SINGULARITY_IMAGE=${VERSION}.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
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

# create required folder 

PLAYGROUND=/beegfs/$USER/jupyter_playground
LOGS=$PLAYGROUND/logs
JWORK=$PLAYGROUND/jupyter_work

mkdir -p $PLAYGROUND
mkdir -p $JWORK
mkdir -p $LOGS

cd $PLAYGROUND

DATE=`date +%Y-%d-%B_%H%M%S`

# required nodes 1
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c ${CORES} -o ${LOGS}/jupyter_lab_${DATE}_%j.log"
SCRIPT_INPUT="${USER} ${LOGIN_HOST} ${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${PLAYGROUND} ${JWORK} ${IMAGE_PATH}"

echo $CMD_LINE_SLURM
echo $SCRIPT_INPUT

BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/jupyter-lab_${VERSION}.sh $SCRIPT_INPUT )

LOG_NAME=${LOGS}/jupyter_lab_${DATE}_${BATCHID}.log
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

2. open http://localhost:8888/lab in your web browser

    Default password: zalfjupyterhpc
    
    Please change your password on first use!
    
END

fi 


