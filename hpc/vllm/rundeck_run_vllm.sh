#!/bin/bash -x
#/ usage: start ?user? ?estimated_time? ?host? ?version?

set -eu
[[ $# < 4 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1 # rundeck user (this job will run as rpm service user, but the ssh tunnel will be created as the rundeck user)
TIME=$2
LOGIN_HOST=$3
VERSION=$4

# run model inference on HPC cluster using SLURM and Singularity
# use H100 GPU node by default, no other GPUs are strong enought 
HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
CORES=128
RESOURCE_REQUEST="-N 1 -c $CORES $HPC_PARTITION" 

#sbatch job name 
SBATCH_JOB_NAME="vllm-inference-${VERSION}"
PORT=11434

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%.18i" -n $SBATCH_JOB_NAME -u $(whoami))

# check if job is running
if [ -z "$BATCHID" ] ; then
   echo "No job running"
else 
   echo "Job is already running"
   echo "If you want to cancel the existing job, use the following command:"
   echo "scancel $BATCHID "

    # TODO:provide connect instructions to the user, including ssh tunnel and web ui url
    NODEHOST=$(squeue --noheader -o "%R" -n $SBATCH_JOB_NAME -u $(whoami) )
    TIME=$(squeue --noheader -o "%.10M" -n $SBATCH_JOB_NAME -u $(whoami) )  
    TIMELEFT=$(squeue --noheader -o "%.10L" -n $SBATCH_JOB_NAME -u $(whoami) )

    echo "Job ID: $BATCHID"
    echo "Node: $NODEHOST"
    echo "Running since: $TIME"
    echo "Time left: $TIMELEFT"

   exit 0
fi


# check if node (gpu005) is available (sinfo gpu005 is idle)
sinfo -N -n gpu005 | grep idle
if [ $? -eq 0 ] ; then
    echo "GPU node gpu005 is available, using it for the job"
else
    echo "GPU node gpu005 is not available"
    exit 1
fi

SINGULARITY_IMAGE=/beegfs/common/singularity/vllm/vllm-openai.${VERSION}.sif
if [ ! -f $SINGULARITY_IMAGE ]; then
    echo "Image not found: $SINGULARITY_IMAGE"
    exit 1
fi
SBATCH_SCRIPT=/beegfs/common/batch/sbatch_vllm-openai.${VERSION}.sh
if [ ! -f $SBATCH_SCRIPT ]; then
    echo "SBATCH script not found: $SBATCH_SCRIPT"
    exit 1
fi
MODEL_DIR=/beegfs/common/models/vllm/${VERSION}
if [ ! -d $MODEL_DIR ]; then
    echo "Model directory not found: $MODEL_DIR"
    exit 1
fi

WHOAMI=$(whoami)

# create required folder
WORKDIR=/beegfs/${WHOAMI}/projects/vllm/${VERSION}
LOGS=$WORKDIR/log

mkdir -p -m 700 $WORKDIR
mkdir -p -m 700 $LOGS

# switch to workdir
cd $WORKDIR

# current date for log naming
DATE=`date +%Y-%d-%B_%H%M%S`


CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${RESOURCE_REQUEST} --time=${TIME} -o ${LOGS}/vllm_${DATE}_%j.log"
SCRIPT_INPUT="${WORKDIR} ${MODEL_DIR} ${SINGULARITY_IMAGE}"

echo $CMD_LINE_SLURM
echo $SCRIPT_INPUT

BATCHID=$( sbatch $CMD_LINE_SLURM $SBATCH_SCRIPT $SCRIPT_INPUT )
LOG_NAME=${LOGS}/vllm_${DATE}_${BATCHID}.log

COUNTER=0
while [ ! -f ${LOG_NAME} ] && [ ! $COUNTER -eq 30 ] ; do 
    sleep 5
    COUNTER=$(($COUNTER + 1))
    if [ $COUNTER == 30 ] ; then
        scancel $BATCHID
        echo "timeout: no free slot available. Try again later"
    fi 
done
sleep 5
if [ -f ${LOG_NAME} ] ; then
   echo "Job started"
   NODEHOST=$(squeue -j ${BATCHID} --noheader --format="%R" )   
else 
   echo "Job not started"
   exit 1
fi 


cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${PORT}:${NODEHOST}:${PORT} ${USER}@${LOGIN_HOST}

2. vscode configure your plugin to connect to the vllm using the following url:
   
   http://localhost:${PORT}

3. please shutdown your job when you are done:

   end the SLURM job with rundeck job:
   "sCancel RPM Slurm Job"
   with this id: ${BATCHID}

END



