#!/bin/bash +x

# TODO: replace by rundeck input parameters
VERSION_VIEW=noconda_p3.12_1
MOUNT_DATA_SOURCE1=none # e.g home,project and common data are mounted by default, these additional mounts can be used for other data sources
MOUNT_DATA_SOURCE2=none # e.g. /beegfs/<other_user>/project/data - data from other users that you have access to
MOUNT_DATA_SOURCE3=none # e.g. /data01/FDS/<user>/data - HPC storage, e.g. for long-term storage or special use cases
READ_ONLY_SOURCES=true # if true, data sources will be mounted as read-only, if false, they will be mounted with read-write permissions (default: true)
TIME="00:15:00" # job runtime
LOCAL_PORT=8888 # local port for ssh tunnel, can be changed if multiple jupyter labs are started or if port 8888 is already used on local machine
LOGIN_HOST="login-node" # name of the login node/ jump host for ssh, e.g. login01, login02, etc. depending on the HPC cluster setup 
PARTITION="10vCPUs-10gb-RAM" # resource specs

JOB_NAME="new_jupyter_lab"

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%.18i" -n $SBATCH_JOB_NAME -u $(whoami))

# check if job is running
if [ -z "$BATCHID" ] ; then
   echo "No job running"

  # version mapping
  # some versions will start with the name "legacy"
  # remove it from the version name if it exists
  VERSION=${VERSION_VIEW#legacy_}
  echo "Requested version: $VERSION_VIEW, using version: $VERSION"

  # create required folder
  WORKDIR=/beegfs/${USER}/jupyter_playground${VERSION}
  LOGS=$WORKDIR/log
  JWORK=$WORKDIR/jupyter_work

  mkdir -p -m 700 $WORKDIR
  mkdir -p -m 700 $LOGS
  mkdir -p $JWORK

  #PASSW=@option.password@
  PASSW="test" # for testing only, replace with rundeck input parameter

  # fail if no password is given
  if [ -z "$PASSW" ] ; then
     echo "No password given"
     exit 1
  fi

  # create hash 
  IMG_FOR_HASH=/beegfs/common/singularity/jupyter/scipy-notebook_lab-3.4.2.sif
  HASH=$(singularity exec $IMG_FOR_HASH python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('$PASSW','sha256'))\")")
  JUPYTER_CONFIG_PATH=$WORKDIR/.jupyter/jupyter_server_config.py
  REQUIRE_SETUP=false
  if [ -e ${JUPYTER_CONFIG_PATH} ] ; then
    # make sure the directory can only be accessed by the user
    chmod 700 $WORKDIR/.jupyter/
    # update password hash
    sed -i "s/c.PasswordIdentityProvider.hashed_password = .*/c.PasswordIdentityProvider.hashed_password = u'$HASH'/g" $JUPYTER_CONFIG_PATH
  else 
    # configuration file does not exist, initial installation required 
    # store password hash to file for later use
    REQUIRE_SETUP=true
    RD_DIR=/beegfs/${USER}/jupyter_playground${VERSION}/.rundeck
    TRANS=${RD_DIR}/jupyter_trans.yml
    mkdir -p -m 700 $RD_DIR
    # make sure the directory can only be accessed by the user
    chmod 700 $RD_DIR
    # write password hash to file
cat <<EOF > ${TRANS}
$HASH
EOF
   fi
   # switch to workdir
   cd $WORKDIR

   # check if jupyter is installed
   # copy over the install script, and check if copied
   cp -f /beegfs/common/batch/ro_installjupyter_${VERSION}.sh .
   STATUS=$?
   if [ $STATUS != 0 ]; then                   
      echo "Copy ro_installjupyter.sh: $STATUS - failed" 
      exit 1
   fi

   # run jupyter install script, with the selected python version (if not already installed)
   export SINGULARITYENV_USE_HTTPS=yes
   export SINGULARITY_HOME=$WORKDIR

   singularity run -H $SINGULARITY_HOME -W $SINGULARITY_HOME --cleanenv \
   -B ${SINGULARITY_HOME}:${SINGULARITY_HOME} \
   $IMAGE_PATH /bin/bash ro_installjupyter_$VERSION.sh $WORKDIR $REQUIRE_SETUP true



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

  # prepare resource request based on partition choice, default is 80vCPUs-80gb-RAM
  HPC_PARTITION="--partition=compute,highmem"
  CORES=80
  MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
  GFX_SUPPORT="false"
  #tiny-2vCPUs-2gb-RAM,
  if [ $PARTITION == "tiny-2vCPUs-2gb-RAM" ] ; then 
    CORES=2
    MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 2GB
  #10vCPUs-10gb-RAM,
  elif [ $PARTITION == "10vCPUs-10gb-RAM" ] ; then 
    CORES=10
    MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 10GB
  #40vCPUs-40gb-RAM,
  elif [ $PARTITION == "40vCPUs-40gb-RAM" ] ; then 
    CORES=40
    MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 40GB
  #80vCPUs-80gb-RAM,
  elif [ $PARTITION == "80vCPUs-80gb-RAM" ] ; then 
    CORES=80
    MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
  #fat-40vCPUs-360gb-RAM,
  elif [ $PARTITION == "fat-40vCPUs-360gb-RAM" ] ; then 
    HPC_PARTITION="--partition=fat"
    CORES=40
    MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 360GB
  #fat-80vCPUs-720gb-RAM,
  elif [ $PARTITION == "fat-80vCPUs-720gb-RAM" ] ; then 
    HPC_PARTITION="--partition=fat"
    CORES=80
    MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 720GB
  #fat-120vCPUs-1tb-RAM,
  elif [ $PARTITION == "fat-120vCPUs-1tb-RAM" ] ; then 
    HPC_PARTITION="--partition=fat"
    CORES=120
    MEM_PER_CPU="--mem-per-cpu=9G" # Total memory: 1080GB
  #compute-full-80vCPUs-90gb-RAM,
  elif [ $PARTITION == "compute-full-80vCPUs-90gb-RAM" ] ; then 
    HPC_PARTITION="--partition=compute"
    CORES=80
    MEM_PER_CPU="" # Total memory: ~90GB
  #highmem-full-80vCPUs-180gb-RAM,
  elif [ $PARTITION == "highmem-full-80vCPUs-180gb-RAM" ] ; then 
    HPC_PARTITION="--partition=highmem"
    CORES=80
    MEM_PER_CPU="" # Total memory: ~180GB
  #fat-full-160vCPUs-1.5tb-RAM
  elif [ $PARTITION == "fat-full-160vCPUs-1.5tb-RAM" ] ; then 
    HPC_PARTITION="--partition=fat"
    CORES=160
    MEM_PER_CPU="" # Total memory: ~1.5TB
  elif [ $PARTITION == "gpu-Tesla-V100" ] ; then 
     HPC_PARTITION="--partition=gpu -x gpu005"
     CORES=48
     MEM_PER_CPU="" # Total memory: ~90GB
     GFX_SUPPORT="true"
  elif [ $PARTITION == "gpu-Nvidia-H100" ] ; then 
     HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
     CORES=128
     MEM_PER_CPU="" # Total memory: ~720GB
     GFX_SUPPORT="true"
  fi

  RESOURCE_REQUEST="-c $CORES $MEM_PER_CPU $HPC_PARTITION" 

  # prepare log directory and file for salloc output
  DATE=$(date +%Y-%m-%d-%H-%M-%S)
  WORKDIR=/home/$USER/logs/allocate
  mkdir -p -m 700 $WORKDIR
  LOGFILE=$WORKDIR/$DATE-out.log

  # trap remove the log file on exit
  function clean_up {
      # remove temporary directory
      rm -f $LOGFILE
      exit
  }
  trap clean_up EXIT

  # Example salloc command:
  # salloc --job-name=myjob -N 1 --immediate=10 --partition=compute -c 2 --mem-per-cpu=1G --time=00:05:00 --no-shell > /home/user/logs/allocate/$(date +%Y-%m-%d-%H-%M-%S)-out.log 2>&1
  # allocate node and redirect standard output and error to log file 
  salloc --job-name=$JOB_NAME --time=$TIME -N 1 $RESOURCE_REQUEST --immediate=10 --no-shell > $LOGFILE 2>&1

  # read the log file to get the node name
  # Example log output:
  # salloc: Granted job allocation 522188
  # salloc: Nodes node053 are ready for job
  JOBID=""
  NODE=""
  while read line; do
      # granted job allocation 
      if [[ $line == *"salloc: Granted job allocation"* ]]; then
          # salloc: Granted job allocation 522188
          # get 522188 from the line
          JOBID=$(echo $line | awk -F ' ' '{print $5}')
          echo "salloc jobid: $JOBID"
      fi

      if [[ $line == *"salloc: Nodes"* ]]; then
          # salloc: Nodes node053 are ready for job
          # get node053 from the line
          NODE=$(echo $line | awk -F ' ' '{print $3}')

          echo "Allocated node: $NODE"
          break
      fi
  done < $LOGFILE

  # check if jobid and node were found
  if [ -z "$JOBID" ]; then
      echo "Error: Could not get job ID from salloc output. Check the log file $LOGFILE for details." >&2
      exit 1
  fi
  if [ -z "$NODE" ]; then
      echo "Error: Could not allocate a node. Check the log file $LOGFILE for details." >&2
      exit 1
  fi

  # use srun to get a free port on the allocated node
  JUPYTER_PORT=$(srun --jobid=${JOBID} python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
  # check if free port was found
  if [ -z "$JUPYTER_PORT" ] ; then
     echo "Error: Could not assign free port on node for jupyter lab" >&2
     scancel $JOBID
     exit 1
  fi
  echo "Free port on allocated node: $JUPYTER_PORT"

  # default mounts
  MOUNT_DATA=/beegfs/common/data
  MOUNT_PROJECT=/beegfs/$USER/
  MOUNT_HOME=/home/$USER

  # get os with python as prepared singularity image
  IMAGE_DIR=/beegfs/common/singularity/python
  SINGULARITY_IMAGE=${VERSION}.sif
  IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

  if [ ! -e ${IMAGE_PATH} ] ; then
   echo "File '${IMAGE_PATH}' not found"
  fi

  LOG_NAME=${LOGS}/jupyter_lab_${DATE}_${JOBID}.log
  SCRIPT_INPUT="${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${WORKDIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${JWORK} ${IMAGE_PATH} ${VERSION} ${JUPYTER_PORT} ${READ_ONLY_SOURCES} ${GFX_SUPPORT}"

  # start jupyter lab on the allocated resources
  # when jupyter exits, scancel releases the allocation automatically
  srun --jobid=${JOBID} -o ${LOG_NAME} sh -c "sh /beegfs/common/batch/ro_jupyter-lab_${VERSION}.sh ${SCRIPT_INPUT}; scancel ${JOBID}" &

  # sleep a bit to catch some error message during startup
  sleep 10

#______________________________________________________________________________________________

# job is already running, retrieve job id and node information
else 
  echo "Job is already running"
  echo "If you want to cancel the existing job, use the following command:"
  echo "scancel $BATCHID "
  echo "or login to your jupyter lab and use 'File->Shut Down' in the jupyterlab menu" 

  NODEHOST=$(squeue --noheader -o "%R" -n $SBATCH_JOB_NAME -u $(whoami) )
  TIME=$(squeue --noheader -o "%.10M" -n $SBATCH_JOB_NAME -u $(whoami) )
  TIMESPAN=$(squeue --noheader -o "%.9l" -n $SBATCH_JOB_NAME -u $(whoami) )

  echo "Job ID: $BATCHID"
  echo "Node: $NODEHOST"
  echo "Running since: $TIME"
  echo "Total time span: $TIMESPAN"

fi 
#______________________________________________________________________________________________

# Note: Will be shown even if job startup fails
# That may cause confusion. In that case, check the log file for details and errors.

cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L ${LOCAL_PORT}:${NODE}:${JUPYTER_PORT} ${USER}@${LOGIN_HOST}

2. open in your web browser:
   
   http://localhost:${LOCAL_PORT}/lab 

3. please shutdown your jupyter after finishing your work with
   
   'File->Shut Down' in the jupyterlab menu
    or end the SLURM job with
   scancel ${JOBID}
    
END
