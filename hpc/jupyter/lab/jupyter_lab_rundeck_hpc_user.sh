#!/bin/bash 
#/ usage: start ?user? ?job_exec_id? ?host? ?estimated_time? ?partition? ?version? ?password? ?port? ?mount_source1? ?mount_source2? ?mount_source3? ?read_only_sources?

set -eu
[[ $# < 12 ]] && {
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
PASSW=$7 #(optional/initial/reset password)
PORT=$8 #(optional port on user PC)
MOUNT_DATA_SOURCE1=$9 # e.g climate data
MOUNT_DATA_SOURCE2=${10} # e.g. project data
MOUNT_DATA_SOURCE3=${11} # e.g. other sources
READ_ONLY_SOURCES=${12}

# fail if no password is given
if [ -z "$PASSW" ] ; then
    echo "No password given"
    exit 1
fi
# if password is none, set to empty string
if [ $PASSW == "none" ] ; then
    PASSW=""
fi

#sbatch job name 
SBATCH_JOB_NAME="jupyter_rdk"

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%.18i" -n $SBATCH_JOB_NAME -u $(whoami))

# check if job is running
if [ -z "$BATCHID" ] ; then
   echo "No job running"
   # check if additional directories are available (else set to none)
   if [ ! -d ${MOUNT_DATA_SOURCE1} ] ; then
   echo "Additional directory '${MOUNT_DATA_SOURCE1}' not found"
   MOUNT_DATA_SOURCE1=none
   fi
   if [ ! -d ${MOUNT_DATA_SOURCE2} ] ; then
   echo "Additional directory '${MOUNT_DATA_SOURCE2}' not found"
   MOUNT_DATA_SOURCE2=none
   fi
   if [ ! -d ${MOUNT_DATA_SOURCE3} ] ; then
   echo "Additional directory '${MOUNT_DATA_SOURCE3}' not found"
   MOUNT_DATA_SOURCE3=none
   fi

   # default mounts
   MOUNT_DATA=/beegfs/common/data
   MOUNT_PROJECT=/beegfs/$USER/
   MOUNT_HOME=/home/$USER

   # create required folder
   WORKDIR=/beegfs/${USER}/jupyter_playground${VERSION}
   LOGS=$WORKDIR/log
   JWORK=$WORKDIR/jupyter_work

   mkdir -p -m 700 $WORKDIR
   mkdir -p -m 700 $LOGS
   mkdir -p $JWORK

   # get jupyter as prepared docker image
   IMAGE_DIR=/beegfs/common/singularity/python
   SINGULARITY_IMAGE=${VERSION}.sif
   IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

   if [ ! -e ${IMAGE_PATH} ] ; then
   echo "File '${IMAGE_PATH}' not found"
   fi

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

   # switch to workdir
   cd $WORKDIR

   # check if jupyter is installed
   # copy over the install script, and check if copied
   cp -f /beegfs/common/batch/installjupyter_${VERSION}.sh .
   STATUS=$?
   if [ $STATUS != 0 ]; then                   
      echo "Copy installjupyter.sh: $STATUS - failed" 
      exit 1
   fi

   # run jupyter install script, with the selected python version (if not already installed)
   export SINGULARITYENV_USE_HTTPS=yes
   export SINGULARITY_HOME=$WORKDIR

   singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
   -B ${SINGULARITY_HOME}:${SINGULARITY_HOME} \
   $IMAGE_PATH /bin/bash installjupyter_$VERSION.sh $WORKDIR $PASSW

   # current date for log naming
   DATE=`date +%Y-%d-%B_%H%M%S`

   # required nodes 1
   CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --time=${TIME} -N 1 -c ${CORES} -o ${LOGS}/jupyter_lab_${DATE}_%j.log"
   SCRIPT_INPUT="${USER} ${LOGIN_HOST} ${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${WORKDIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${JWORK} ${IMAGE_PATH} ${VERSION}"

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
      echo "Job started"
      NODEHOST=$(squeue -j ${BATCHID} --noheader --format="%R" )   
   else 
      echo "Job not started"
      exit 1
   fi 
else 
      echo "Job is already running"
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

   ssh -N -L ${PORT}:${NODEHOST}:8888 ${USER}@${LOGIN_HOST}

2. open in your web browser:
   
   http://localhost:${PORT}/lab 

3. please shutdown your jupyter after finishing your work with
   
   'File->Shut Down' in the jupyterlab menu
    or end the SLURM job with
   scancel ${BATCHID}
    
END



