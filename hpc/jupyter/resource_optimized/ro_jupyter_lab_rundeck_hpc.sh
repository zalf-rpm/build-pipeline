#!/bin/bash -x
#/ usage: start ?login-host? ?estimated_time? ?partition? ?version? ?local-port? ?mount_source1? ?mount_source2? ?mount_source3? ?read_only_sources? 

set -eu
[[ $# < 9 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

LOGIN_HOST=$1 # name of the login node/ jump host for ssh, e.g. login01, login02, etc. depending on the HPC cluster setup
TIME=$2 # job runtime, e.g. 00:15:00
PARTITION=$3 # resource specs (e.g. "10vCPUs-10gb-RAM", see below for possible values)
VERSION_VIEW=$4 # version of jupyter lab environment, e.g. "noconda_p3.10_10", "legacy_noconda_p3.10_10" (legacy versions will be kept for some time for reproducibility reasons, but will not be updated anymore, new versions will not have the "legacy" prefix)
LOCAL_PORT=$5 # local port for ssh tunnel, can be changed if multiple jupyter labs are started or if port 8888 is already used on local machine

# home,project and common data are mounted by default, these additional mounts can be used for other data sources
# e.g. /beegfs/<other_user>/project/data - data from other users that you have access to
# e.g. /data01/FDS/<user>/data - HPC storage, e.g. for long-term storage or special use cases
MOUNT_DATA_SOURCE1=$6 # e.g climate data
MOUNT_DATA_SOURCE2=$7 # e.g. project data
MOUNT_DATA_SOURCE3=$8 # e.g. other sources
READ_ONLY_SOURCES=$9 # if true, data sources will be mounted as read-only, if false, they will be mounted with read-write permissions (default: true)

JOB_NAME="jupyter_lab_gen"

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%.18i" -n $JOB_NAME -u $(whoami))

# version mapping
# some versions will start with the name "legacy"
# remove it from the version name if it exists
VERSION=${VERSION_VIEW#legacy_}
echo "Requested version: $VERSION_VIEW, using version: $VERSION"

# check if job is running
if [ -z "$BATCHID" ] ; then
   echo "No job running"

  # create required folder
  WORKDIR=/beegfs/${USER}/jupyter_playground${VERSION}
  LOGS=$WORKDIR/log
  JWORK=$WORKDIR/jupyter_work

  mkdir -p -m 700 $WORKDIR
  mkdir -p -m 700 $LOGS
  mkdir -p $JWORK

  PASSW=@option.password@

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

   # get os with python as prepared singularity image
  IMAGE_DIR=/beegfs/common/singularity/python
  SINGULARITY_IMAGE=${VERSION}.sif
  IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}
 
  if [ ! -e ${IMAGE_PATH} ] ; then
    echo "File '${IMAGE_PATH}' not found"
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
# tiny-2vCPUs-2gb-RAM,10vCPUs-10gb-RAM,40vCPUs-40gb-RAM,80vCPUs-80gb-RAM,fat-40vCPUs-360gb-RAM,fat-80vCPUs-720gb-RAM,fat-120vCPUs-1tb-RAM,compute-full-80vCPUs-90gb-RAM,highmem-full-80vCPUs-180gb-RAM,fat-full-160vCPUs-1.5tb-RAM,gpu-Tesla-V100,gpu-Nvidia-H100
  RESOURCE_REQUEST="-c $CORES $MEM_PER_CPU $HPC_PARTITION" 

  DATE=$(date +%Y-%m-%d-%H-%M-%S)
  LOG_NAME=${LOGS}/jupyter_lab_${DATE}_%j.log
  # default mounts
  MOUNT_DATA=/beegfs/common/data
  MOUNT_PROJECT=/beegfs/$USER/
  MOUNT_HOME=/home/$USER


  SBATCH_CMD=" --parsable --job-name=$JOB_NAME --time=$TIME -N 1 $RESOURCE_REQUEST -o ${LOG_NAME} -e ${LOG_NAME} "
  SCRIPT_INPUT="${MOUNT_PROJECT} ${MOUNT_DATA} ${MOUNT_HOME} ${WORKDIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${JWORK} ${IMAGE_PATH} ${VERSION} ${READ_ONLY_SOURCES} ${GFX_SUPPORT} ${LOCAL_PORT} ${LOGIN_HOST}"

  # start sbatch job to run jupyter lab with prepared script input and resource request
  BATCHID=$(sbatch $SBATCH_CMD /beegfs/common/batch/ro_jupyter-lab_${VERSION}.sh ${SCRIPT_INPUT} )

  # wait for launch file to be created by sbatch script, check every 5 seconds, and print launch instructions for ssh tunnel and jupyter access once file is created
  sleep 5
  LAUNCH_FILE=/beegfs/${USER}/jupyter_playground${VERSION}/.launch_instructions/${BATCHID}.rundeck

  # count to 30 or till a launch file is created, 
  # then timeout and cancel job if no launch file is created
  COUNTER=0
  while [ ! -f ${LAUNCH_FILE} ] && [ ! $COUNTER -eq 30 ] ; do 
  sleep 5
  COUNTER=$(($COUNTER + 1))
  if [ $COUNTER == 30 ] ; then
      scancel $BATCHID
      echo "timeout: no free slot available. Try again later"
      exit 1
  fi 
  done
  # make sure jupyter has started and is ready to accept connections before printing launch instructions, 
  #otherwise user may try to connect too early and get connection error
  sleep 10 

#______________________________________________________________________________________________

# job is already running, retrieve job id and node information
else 
  # remove leading and trailing whitespaces from BATCHID
  BATCHID=$(echo $BATCHID | xargs)

  echo "Job is already running"
  echo "If you want to cancel the existing job, use the following command:"
  echo "scancel $BATCHID "
  echo "or login to your jupyter lab and use 'File->Shut Down' in the jupyterlab menu" 

  NODE=$(squeue --noheader -o "%R" -n $JOB_NAME -u $(whoami) )
  TIME=$(squeue --noheader -o "%.10M" -n $JOB_NAME -u $(whoami) )
  TIMESPAN=$(squeue --noheader -o "%.9l" -n $JOB_NAME -u $(whoami) )

  echo "Job ID: $BATCHID"
  echo "Node: $NODE"
  echo "Running since: $TIME"
  echo "Total time span: $TIMESPAN"

  LAUNCH_FILE=/beegfs/${USER}/jupyter_playground${VERSION}/.launch_instructions/${BATCHID}.rundeck
fi 

#______________________________________________________________________________________________

# Note: Will be shown even if job startup fails
# That may cause confusion. In that case, check the log file for details and errors.

# print launch instructions for ssh tunnel and jupyter access
if [ -f ${LAUNCH_FILE} ] ; then
    cat ${LAUNCH_FILE}
else
    echo "Launch instructions file not found: ${LAUNCH_FILE}"
    echo "Check if job is running with a different version"
fi 