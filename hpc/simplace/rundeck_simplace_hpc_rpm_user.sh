#!/bin/bash
#/ usage: start ?user? ?job_name? ?job_exec_id? ?solution_path? ?project_path? ?version? ?lines? ?debug? ?estimated_time? ?used_cpu? ?mount_data? ?mount_project? ?use_high_memory?
set -eu
[[ $# != 12 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin


USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
SOLUTION_PATH=$4
PROJECT_PATH=$5
VERSION=$6
DEBUG=$7
TIME=$8
MOUNT_DATA=$9
MOUNT_PROJECT=${10}
NODES=${11}
MEMORY=${12}

USER_FOLDER=/beegfs/rpm/projects/simplace_user/${USER}

# check if user folder exists
if [ ! -d "$USER_FOLDER" ]; then
  mkdir -p $USER_FOLDER
  chmod 755 $USER_FOLDER
fi


SIMPLACE_WORK=${USER_FOLDER}/SIMPLACE_WORK
# check if simplace work folder exists
if [ ! -d "$SIMPLACE_WORK" ]; then
  # this folder contains the setup, if it is not there, create the folder
  # this will help the user to get the correct folder structure for simplace simulation.
  echo "Simplace work folder $SIMPLACE_WORK does not exist."
  echo "Creating the folder structure for you."
  mkdir -p  $SIMPLACE_WORK
  # this is the only folder where the user has write access, so we set the permissions to 777, 
  # so the user can copy his simulation data into this folder.
  chmod 777 $SIMPLACE_WORK
  echo "Please copy your simulation data into $SIMPLACE_WORK."
  exit 1
fi

# check if all files are in place, before creating the output folders, so we do not create a lot of empty folders.
#check if the singularity image exists 
SINGULARITY_IMAGE=simplace_${VERSION}.sif
IMAGE_DIR=/beegfs/common/singularity/simplace
if [ ! -e ${IMAGE_DIR}/${SINGULARITY_IMAGE} ] ; then
echo "File '${IMAGE_DIR}/${SINGULARITY_IMAGE}' not found"
exit 1
fi
# check if solution file exists
if [ ! -f "$SIMPLACE_WORK/$SOLUTION_PATH" ]; then
  echo "Solution file $SIMPLACE_WORK/$SOLUTION_PATH does not exist."
  echo "Please check the solution path."
  exit 1
fi
# check if project file exists
if [ ! -f "$SIMPLACE_WORK/$PROJECT_PATH" ]; then
  echo "Project file $SIMPLACE_WORK/$PROJECT_PATH does not exist."
  echo "Please check the project path."
  exit 1
fi
# check if mount data path exists (mount data path is the path where the user has access to the data, e.g. /beegfs/common/data)
if [ ! -d "$MOUNT_DATA" ]; then
  echo "Mount data path $MOUNT_DATA does not exist."
  echo "Please check the mount data path."
  exit 1
fi
# check if mount project path exists (mount project path is the path where the user has access to the project, e.g. /beegfs/rpm/projects/simplace/projects)
if [ ! -d "$MOUNT_PROJECT" ]; then
  echo "Mount project path $MOUNT_PROJECT does not exist."
  echo "Please check the mount project path."
  exit 1
fi

# create output folders, readable for all users, but writable only for the user
SIMPLACE_RUNS=${USER_FOLDER}/runs
mkdir -p $SIMPLACE_RUNS
chmod 755 $SIMPLACE_RUNS

DATE=`date +%Y-%d-%B_%H%M%S`
RUN_ID=${DATE}_${JOB_EXEC_ID}

SIMPLACE_RUN=${SIMPLACE_RUNS}/${RUN_ID}
mkdir -p $SIMPLACE_RUN
chmod 755 $SIMPLACE_RUN

SIMPLACE_OUT=${SIMPLACE_RUN}/out
mkdir -p $SIMPLACE_OUT
chmod 755 $SIMPLACE_OUT
SIMPLACE_OUT_ZIP=${SIMPLACE_RUN}/output_zip
mkdir -p $SIMPLACE_OUT_ZIP
chmod 755 $SIMPLACE_OUT_ZIP
SIMPLACE_LOG=${SIMPLACE_RUN}/log
mkdir -p $SIMPLACE_LOG
chmod 755 $SIMPLACE_LOG

# check if job name is empty 
if [ -z "$JOB_NAME" ] ; then 
    JOB_NAME="generic"
fi 
# job name should only contain letters, numbers, lines and underscores, so we replace all other characters with underscores
JOB_NAME=$(echo $JOB_NAME | sed 's/[^a-zA-Z0-9_-]/_/g')

#sbatch job name 
SBATCH_JOB_NAME="simpl_${JOB_NAME}"

# options: tiny, normal, high, veryhigh (default: normal)
CPU="--cpus-per-task=40"
HPC_PARTITION="--partition=compute,highmem"
MEMORY_USAGE="--mem-per-cpu=1G" # default memory usage per cpu, can be overwritten by high memory option
if [ $MEMORY == "tiny" ] ; then 
  CPU="--cpus-per-task=16" 
  MEMORY_USAGE="--mem-per-cpu=2G" # total: cpu*mem = 32G
elif [ $MEMORY == "normal" ] ; then 
  CPU="--cpus-per-task=40"
  MEMORY_USAGE="--mem-per-cpu=1G" # total: cpu*mem = 40G
elif [ $MEMORY == "high" ] ; then 
  MEMORY_USAGE="--mem-per-cpu=2G" # total: cpu*mem = 80G
elif [ $MEMORY == "veryhigh" ] ; then 
  HPC_PARTITION="--partition=highmem"
  MEMORY_USAGE="--mem-per-cpu=4G" # total: cpu*mem = 160G
fi

MOUNT_WORK=$SIMPLACE_WORK
MOUNT_OUT=$SIMPLACE_OUT
MOUNT_OUT_ZIP=$SIMPLACE_OUT_ZIP/single_outputs
mkdir $MOUNT_OUT_ZIP
chmod 755 $MOUNT_OUT_ZIP

# change to working directory
cd $USER_FOLDER
SCRIPT_DIR=/beegfs/common/singularity/simplace/scripts

#extract lines
LINE_SPLITUPSTR=$( srun --partition=compute,highmem,fat,gpu --cpus-per-task=2 --mem-per-cpu=1G --job-name=${SBATCH_JOB_NAME}_srun singularity run -B \
$MOUNT_WORK:/simplace/SIMPLACE_WORK,\
$MOUNT_DATA:/data,\
$MOUNT_PROJECT:/projects \
${IMAGE_DIR}/${SINGULARITY_IMAGE} /splitsimplaceproj/splitsimplaceproj /simplace/SIMPLACE_WORK/$PROJECT_PATH 1 $NODES _WORKDIR_?/simplace/SIMPLACE_WORK _PROJECTSDIR_?/projects _DATADIR_?/data)



DEPENDENCY=afterany
IFS=',' # (,) is set as delimiter
read -ra ADDR <<< "$LINE_SPLITUPSTR" # str is read into an array as tokens separated by IFS

for i in "${ADDR[@]}"; do # access each element of array
    IFS='-' # (-) is set as delimiter
    read -ra SOME <<< "$i" # string is read into an array as tokens separated by IFS
    IFS=' ' # reset to default value after usage
    STARTLINE=${SOME[0]}
    ENDLINE=${SOME[1]}
	#sbatch commands
	SBATCH_COMMANDS="--parsable --job-name=${SBATCH_JOB_NAME}_${i} --time=${TIME} ${CPU} ${MEMORY_USAGE} ${HPC_PARTITION} -o $SIMPLACE_LOG/simplace-%j"
	#simplace sbatch script commands
    SIMPLACE_INPUT="${MOUNT_DATA} ${MOUNT_WORK} ${MOUNT_OUT} ${MOUNT_OUT_ZIP} ${MOUNT_PROJECT} ${SIMPLACE_LOG} ${SOLUTION_PATH} ${PROJECT_PATH} ${IMAGE_DIR}/${SINGULARITY_IMAGE} ${DEBUG} ${STARTLINE} ${ENDLINE} ${SBATCH_JOB_NAME}_${i} false"
    echo "First  $STARTLINE"
    echo "Second $ENDLINE"
    echo "$i"

	echo "sbatch $SBATCH_COMMANDS $SCRIPT_DIR/sbatch_simplace.sh $SIMPLACE_INPUT"
	BATCHID=$( sbatch $SBATCH_COMMANDS $SCRIPT_DIR/sbatch_simplace.sh $SIMPLACE_INPUT )
  DEPENDENCY=$DEPENDENCY":"$BATCHID
  echo "DEPENDENCY: $DEPENDENCY"
done

# accumulate results into one folder structure
MOUNT_OUT_ZIP_ACC=${SIMPLACE_OUT_ZIP}/acc
mkdir $MOUNT_OUT_ZIP_ACC

DEP_COMAND="sbatch --dependency=$DEPENDENCY --partition=compute,highmem --job-name=${SBATCH_JOB_NAME}_ACC --time=05:15:00 --cpus-per-task=2 --mem-per-cpu=4G -o $SIMPLACE_LOG/simplace-acc%j $SCRIPT_DIR/sbatch_acc_simplace.sh $MOUNT_OUT_ZIP $MOUNT_OUT_ZIP_ACC ${IMAGE_DIR}/${SINGULARITY_IMAGE} "

echo "ACCUMULATE: ${DEP_COMAND}"
$DEP_COMAND