#!/bin/bash
#/ usage: start user job_exec_id login_host time resources version project_dir [mount_source1] [mount_source2] [mount_source3] [mount_data_out]
#/ optional mounts can be empty or "none"

set -eu
[[ $# -lt 7 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2 # from rundeck, for matching the job with the rundeck job execution
LOGIN_HOST=$3 # login host for the HPC cluster, e.g. to print the login command for the user to connect to the HPC cluster
TIME=$4 # timelimit for the job, e.g. 2:00:00 for 2 hours
RESOURCES=$5 # resources definition for the job, maps to CPU, GPU, memory
VERSION=$6 # version of the base image to use, e.g. 0.4 for ai-harness_0.4.sif
PROJECT_DIR=$7 # project directory to mount in the container, e.g. /beegfs/$USER/my_project
# optional mounts: empty values would shift the positional arguments of the sbatch script, so always use "none"
MOUNT_DATA_SOURCE1=${8:-none} # e.g climate data (optional mount source, read-only)
MOUNT_DATA_SOURCE2=${9:-none} # e.g. project data (optional, read-only)
MOUNT_DATA_SOURCE3=${10:-none} # e.g. other sources (optional, read-only)
MOUNT_DATA_OUT=${11:-none} # e.g. output data directory (optional, read-write)

[ -z "$MOUNT_DATA_SOURCE1" ] && MOUNT_DATA_SOURCE1=none
[ -z "$MOUNT_DATA_SOURCE2" ] && MOUNT_DATA_SOURCE2=none
[ -z "$MOUNT_DATA_SOURCE3" ] && MOUNT_DATA_SOURCE3=none
[ -z "$MOUNT_DATA_OUT" ] && MOUNT_DATA_OUT=none

JOB_NAME=ide_${JOB_EXEC_ID}
LOGS=/beegfs/$USER/ide/logs
LAUNCH_DIR=/beegfs/$USER/ide/.launch_instructions
mkdir -p "$LOGS"
mkdir -p "$LAUNCH_DIR"
chmod 700 "/beegfs/$USER/ide" "$LAUNCH_DIR"

# TBD: only project directory and output data directory should be mounted as read-write,
# all other directories should be mounted as read-only
# TODO: check with users later

# Validate all user given paths and collect ALL problems, so the user can fix everything in one go.
# Empty or "none" means "not used". Everything else must be valid, otherwise we abort before anything is submitted.
ERRORS=0
fail() { echo "ERROR: $1" >&2; ERRORS=$((ERRORS + 1)); }

check_dir() { # $1 = parameter name, $2 = directory, $3 = "rw" or "ro"
  local name="$1" dir="$2" mode="$3"
  [ "$dir" = "none" ] && return 0
  if [ ! -d "$dir" ]; then fail "$name: directory '$dir' does not exist"; return 0; fi
  if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then fail "$name: directory '$dir' is not readable by user $USER"; return 0; fi
  if [ "$mode" = "rw" ] && [ ! -w "$dir" ]; then fail "$name: directory '$dir' is not writable by user $USER"; fi
  return 0
}

check_dir PROJECT_DIR "$PROJECT_DIR" rw
check_dir MOUNT_DATA_SOURCE1 "$MOUNT_DATA_SOURCE1" ro
check_dir MOUNT_DATA_SOURCE2 "$MOUNT_DATA_SOURCE2" ro
check_dir MOUNT_DATA_SOURCE3 "$MOUNT_DATA_SOURCE3" ro

# the output directory is created by the sbatch script if missing:
# then the closest existing parent must be writable
if [ "$MOUNT_DATA_OUT" != "none" ]; then
  if [ -d "$MOUNT_DATA_OUT" ]; then
    check_dir MOUNT_DATA_OUT "$MOUNT_DATA_OUT" rw
  else
    PARENT=$(dirname "$MOUNT_DATA_OUT")
    while [ ! -d "$PARENT" ] && [ "$PARENT" != "/" ]; do PARENT=$(dirname "$PARENT"); done
    if [ ! -w "$PARENT" ]; then
      fail "MOUNT_DATA_OUT: '$MOUNT_DATA_OUT' does not exist and cannot be created ('$PARENT' is not writable by user $USER)"
    fi
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Aborted: $ERRORS problem(s) with the given directories. Please correct the parameters and start again." >&2
  exit 1
fi

# get base image as singularity image path
IMAGE_DIR=/beegfs/common/singularity/ai-harness
SINGULARITY_IMAGE=${VERSION}.sif # the version is the name of the singularity image, e.g. ai-harness_0.4.sif, ubuntu26-harness_0.4.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}

if [ ! -e "$IMAGE_PATH" ] ; then
  echo "File '${IMAGE_PATH}' not found" >&2
  exit 1
fi

SBATCH_SCRIPT=/beegfs/common/batch/sbatch_start_ide_container_${VERSION}.sh
if [ ! -e "$SBATCH_SCRIPT" ] ; then
  echo "File '${SBATCH_SCRIPT}' not found" >&2
  exit 1
fi

# prepare resource request based on partition choice, default is 80vCPUs-80gb-RAM
HPC_PARTITION="--partition=compute,highmem"
CORES=80
MEM_PER_CPU="--mem-per-cpu=1G" # Total memory: 80GB
case "$RESOURCES" in
  tiny-2vCPUs-2gb-RAM)
    CORES=2;  MEM_PER_CPU="--mem-per-cpu=1G" ;; # Total memory: 2GB
  10vCPUs-10gb-RAM)
    CORES=10; MEM_PER_CPU="--mem-per-cpu=1G" ;; # Total memory: 10GB
  40vCPUs-40gb-RAM)
    CORES=40; MEM_PER_CPU="--mem-per-cpu=1G" ;; # Total memory: 40GB
  80vCPUs-80gb-RAM)
    CORES=80; MEM_PER_CPU="--mem-per-cpu=1G" ;; # Total memory: 80GB
  fat-40vCPUs-360gb-RAM)
    HPC_PARTITION="--partition=fat"; CORES=40;  MEM_PER_CPU="--mem-per-cpu=9G" ;; # Total memory: 360GB
  fat-80vCPUs-720gb-RAM)
    HPC_PARTITION="--partition=fat"; CORES=80;  MEM_PER_CPU="--mem-per-cpu=9G" ;; # Total memory: 720GB
  fat-120vCPUs-1tb-RAM)
    HPC_PARTITION="--partition=fat"; CORES=120; MEM_PER_CPU="--mem-per-cpu=9G" ;; # Total memory: 1080GB
  compute-full-80vCPUs-90gb-RAM)
    HPC_PARTITION="--partition=compute"; CORES=80; MEM_PER_CPU="" ;; # Total memory: ~90GB
  highmem-full-80vCPUs-180gb-RAM)
    HPC_PARTITION="--partition=highmem"; CORES=80; MEM_PER_CPU="" ;; # Total memory: ~180GB
  fat-full-160vCPUs-1.5tb-RAM)
    HPC_PARTITION="--partition=fat"; CORES=160; MEM_PER_CPU="" ;; # Total memory: ~1.5TB
  gpu-Tesla-V100)
    HPC_PARTITION="--partition=gpu -x gpu005"; CORES=48; MEM_PER_CPU="" ;; # Total memory: ~90GB
  gpu-Nvidia-H100)
    HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"; CORES=128; MEM_PER_CPU="" ;; # Total memory: ~720GB
  *)
    echo "Unknown resources definition '${RESOURCES}', using default 80vCPUs-80gb-RAM" >&2 ;;
esac

# text for the rundeck selection box
# give user some guidance on the resources
# markdown section:
# **Start small, find out what you need, then scale up.** The following resources are available:  
# tiny-2vCPUs-2gb-RAM: small jobs, e.g. testing, writing small scripts  
# 10vCPUs-10gb-RAM: small jobs, e.g. testing, debugging, small data analysis  
# 40vCPUs-40gb-RAM: should suffice for most jobs, e.g. data analysis  
# 80vCPUs-80gb-RAM: large jobs, e.g. data analysis  
# fat-40vCPUs-360gb-RAM: very large jobs, e.g. data analysis with large datasets, satellite imagery, genomics etc.  
# fat-80vCPUs-720gb-RAM: very large jobs, e.g. data analysis with large datasets, satellite imagery, genomics etc.  
# fat-120vCPUs-1tb-RAM: very large jobs, e.g. data analysiswith large datasets, satellite imagery, genomics etc.  
# compute-full-80vCPUs-90gb-RAM: exclusive access compute node 
# highmem-full-80vCPUs-180gb-RAM: exclusive access highmem node for memory-intensive jobs  
# fat-full-160vCPUs-1.5tb-RAM: exclusive access fat node 
# gpu-Tesla-V100: exclusive access GPU node, use for deep learning jobs, e.g. training models, running inference on large datasets, etc.  
# gpu-Nvidia-H100: exclusive access to GPU node, use for large deep learning jobs, e.g. training large models, running inference on large datasets, etc.  


RESOURCE_REQUEST="-c $CORES $MEM_PER_CPU $HPC_PARTITION"

DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOG_NAME=${LOGS}/ai_harness_${DATE}_%j.log

SBATCH_CMD="--parsable --job-name=$JOB_NAME --time=$TIME -N 1 $RESOURCE_REQUEST -o ${LOG_NAME} -e ${LOG_NAME}"
# argument order must match the sbatch script
SCRIPT_INPUT="${PROJECT_DIR} ${MOUNT_DATA_SOURCE1} ${MOUNT_DATA_SOURCE2} ${MOUNT_DATA_SOURCE3} ${MOUNT_DATA_OUT} ${IMAGE_PATH} ${LOGIN_HOST} ${LAUNCH_DIR}"

# word splitting of SBATCH_CMD / SCRIPT_INPUT is intended (paths with spaces are not supported)
BATCHID=$(sbatch $SBATCH_CMD "$SBATCH_SCRIPT" $SCRIPT_INPUT)
BATCHID=${BATCHID%%;*} # --parsable may append ";cluster"
echo "Submitted batch job $BATCHID"

# wait for launch file to be created by sbatch script (it is written once sshd is listening)
LAUNCH_FILE=$LAUNCH_DIR/${BATCHID}.rundeck
MAX_WAIT=60 # x 5 seconds = 5 minutes
COUNTER=0
while [ ! -f "${LAUNCH_FILE}" ] ; do
  sleep 5
  COUNTER=$((COUNTER + 1))
  # stop waiting if the job is gone (failed / cancelled), the log has the reason
  STATE=$(squeue -h -j "$BATCHID" -o %T 2>/dev/null || true)
  if [ -z "$STATE" ] && [ ! -f "${LAUNCH_FILE}" ] ; then
    echo "Job $BATCHID ended before the session was ready. See log in ${LOGS}" >&2
    exit 1
  fi
  if [ "$COUNTER" -ge "$MAX_WAIT" ] ; then
    scancel "$BATCHID"
    echo "timeout: no free slot available. Try again later" >&2
    exit 1
  fi
done

# print launch instructions for ssh tunnel and access
cat "${LAUNCH_FILE}"
