#!/bin/bash -x
#/ usage: start ?user? ?host? ?estimated_time?

set -eu
[[ $# < 3 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
TIME=$2
LOGIN_HOST=$3

PARTITION=compute #(partition to use, maybe extended to highmem, gpu-Tesla-V100, gpu-Nvidia-H100, fat later)
VERSION=0.5.7 #(ollama version)
PORT=8080 #(optional port on user PC)
#sbatch job name 
SBATCH_JOB_NAME="ollama-webui"

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%.18i" -n $SBATCH_JOB_NAME -u $(whoami))

WORKDIR=/beegfs/${USER}/ollama${VERSION}
MOUNT_OLLAMA=${WORKDIR}/ollama
MOUNT_OPEN_WEB_UI=${WORKDIR}/open_web_ui
LOGS=$WORKDIR/log
SINGULARITY_IMAGE=/beegfs/common/singularity/ollama/ollama-hpc_${VERSION}.sif

# check if job is running
if [ -z "$BATCHID" ] ; then
   echo "No job running"
    # create required folder



   # check if that is the inital run, by checking if the folder exists
   SLEEPTIME=30
   if [ -d $MOUNT_OPEN_WEB_UI ]; then
      SLEEPTIME=10
   fi
   

    mkdir -p -m 700 $WORKDIR
    mkdir -p -m 700 $MOUNT_OLLAMA
    mkdir -p -m 700 $MOUNT_OPEN_WEB_UI
    mkdir -p -m 700 $LOGS

    # check if the image exists
    if [ ! -f $SINGULARITY_IMAGE ]; then
        echo "Image not found: $SINGULARITY_IMAGE"
        exit 1
    fi

   HPC_PARTITION="--partition=compute"
   CORES=80
   echo "warning..."
   if [ $PARTITION == "highmem" ] ; then 
     HPC_PARTITION="--partition=highmem"
     CORES=80
   elif [ $PARTITION == "gpu-Tesla-V100" ] ; then 
     HPC_PARTITION="--partition=gpu -x gpu005"
     CORES=48
   elif [ $PARTITION == "gpu-Nvidia-H100" ] ; then 
     HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
     CORES=128
   elif [ $PARTITION == "fat" ] ; then 
     HPC_PARTITION="--partition=fat"
     CORES=160
   fi

   # switch to workdir
   cd $WORKDIR

   export SINGULARITYENV_USE_HTTPS=yes
   export SINGULARITY_HOME=$WORKDIR

   # current date for log naming
   DATE=`date +%Y-%d-%B_%H%M%S`
   # required nodes 1

   CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c ${CORES} -o ${LOGS}/ollama_open_webui_${DATE}_%j.log"
   SCRIPT_INPUT="${WORKDIR} ${MOUNT_OLLAMA} ${MOUNT_OPEN_WEB_UI} ${SINGULARITY_IMAGE}"

   echo $CMD_LINE_SLURM
   echo $SCRIPT_INPUT

   BATCHID=$( sbatch $CMD_LINE_SLURM /beegfs/common/batch/ollama_open_webui_${VERSION}.sh $SCRIPT_INPUT )
   LOG_NAME=${LOGS}/ollama_open_webui_${DATE}_${BATCHID}.log

   COUNTER=0
   while [ ! -f ${LOG_NAME} ] && [ ! $COUNTER -eq 30 ] ; do 
   sleep 10
   COUNTER=$(($COUNTER + 1))
   if [ $COUNTER == 30 ] ; then
       scancel $BATCHID
       echo "timeout: no free slot available. Try again later"
   fi 
   done
   sleep $SLEEPTIME
   if [ -f ${LOG_NAME} ] ; then
      #cat ${LOG_NAME}
      echo "Job started"
      NODEHOST=$(squeue -j ${BATCHID} --noheader --format="%R" )   
   else 
      echo "Job not started"
      exit 1
   fi 
else 
      echo "Job is already running"
      echo "If you want to cancel the existing job, use the following command:"
      echo "scancel $BATCHID "

      NODEHOST=$(squeue --noheader -o "%R" -n $SBATCH_JOB_NAME -u $(whoami) )
      TIME=$(squeue --noheader -o "%.10M" -n $SBATCH_JOB_NAME -u $(whoami) )
      TIMESPAN=$(squeue --noheader -o "%.9l" -n $SBATCH_JOB_NAME -u $(whoami) )

      echo "Job ID: $BATCHID"
      echo "Node: $NODEHOST"
      echo "Running since: $TIME"
      echo "Total time span: $TIMESPAN"

fi 

cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${PORT}:${NODEHOST}:8080 ${USER}@${LOGIN_HOST}

2. open in your web browser:
   Please note, intial setup may take a minute or two.
   First login requires that you set up an admin account, do it before someone else does.
   
   http://localhost:${PORT}

3. please shutdown your job when you are done:

   end the SLURM job with
   scancel ${BATCHID}
   
4. You forgot your admin password:
   Stop the job and delete ${MOUNT_OPEN_WEB_UI}
   Than start the job again.
   Please note, your conversation history will be lost.
   Consider using a password manager to store your password.

END



