#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?project_folder? ?sim_folder? ?estimated_time? ?use_nodes?
set -eu
[[ $# < 7 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
PROJECT_FOLDER=$4
SIM_FOLDER=$5
TIME=$6
NUM_NODES=$7 
CLIMATE_FOLDER=$8

SBATCH_JOB_NAME="apsim_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"
DATE=`date +%Y-%d-%B_%H%M%S`

APSIM_TEMP=~/apsim_run${DATE}
mkdir -p $APSIM_TEMP

SINGULARITY_IMAGE=/home/rpm/singularity/apsim/apsim-classic_79.1.sif
SOURCE_FOLDER=${PROJECT_FOLDER}/${SIM_FOLDER}
OUT_FOLDER=${PROJECT_FOLDER}/out_${DATE}
mkdir -p $OUT_FOLDER

~/batch/apsimcreatebatch/createapsimbatch -path ${SOURCE_FOLDER} -temp $APSIM_TEMP -numnodes $NUM_NODES

DEPENDENCY=afterany
JOBFILES=$APSIM_TEMP/*
INDEX=0
for jobfile in ${JOBFILES}; do
    echo "start jobfile" $jobfile
    INDEX=`expr $INDEX + 1`
	SBATCH_COMMANDS="--parsable --job-name=${SBATCH_JOB_NAME}_${INDEX} --time=${TIME} -N 1 -c 80 -o log/apsim_batch-%j" 
	BATCHID=$( sbatch $SBATCH_COMMANDS batch/sbatch_parallel_apsim3.sh $PROJECT_FOLDER $CLIMATE_FOLDER $SIM_FOLDER $SINGULARITY_IMAGE $jobfile $OUT_FOLDER )
	DEPENDENCY=$DEPENDENCY":"$BATCHID
  	echo "DEPENDENCY: $DEPENDENCY"
done

sbatch --dependency=$DEPENDENCY --job-name=${SBATCH_JOB_NAME}_cleanup --time=12:00:00 -o log/apsim_batch-_cleanup%j batch/sbatch_apsim_batch_cleanup.sh $APSIM_TEMP $SOURCE_FOLDER $OUT_FOLDER

