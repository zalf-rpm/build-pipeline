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

SBATCH_JOB_NAME="apsim_${USER}_${JOB_NAME}_${JOB_EXEC_ID}"
DATE=`date +%Y-%d-%B_%H%M%S`

APSIM_TEMP=~/apsim_run${DATE}

SINGULARITY_IMAGE=/home/rpm/singularity/apsim/apsim-classic_79.1.sif
SOURCE_FOLDER=${PROJECT_FOLDER}/${SIM_FOLDER}
OUT_FOLDER=${PROJECT_FOLDER}/out_${DATE}


COUNT=`ls ${SOURCE_FOLDER}/*.apsim | wc -l`

NUM_PER_JOB=`expr $COUNT / $NUM_NODES`

if [ `expr $COUNT % $NUM_NODES` -ne 0 ] ; then
  NUM_PER_JOB=`expr $NUM_PER_JOB + 1`
fi
echo "max simulation per job:" $NUM_PER_JOB

FILES=${SOURCE_FOLDER}/*.apsim
mkdir -p $APSIM_TEMP
mkdir $OUT_FOLDER

INDEX_SIMFILE=0
JOBFILE=jobfile.txt
FILE_INDEX=0
for file in ${FILES}; do
	INDEX_SIMFILE=`expr $INDEX_SIMFILE + 1`
	if [ ${INDEX_SIMFILE} -eq 1 ] ; then 
		FILE_INDEX=`expr $FILE_INDEX + 1`
		JOBFILE=$APSIM_TEMP/jobfile${FILE_INDEX}.txt
		touch $JOBFILE
		echo $JOBFILE
	fi
	
	echo `basename "${file}"` >> $JOBFILE
	#echo $INDEX_SIMFILE `basename "${file}"`
	if [ "${INDEX_SIMFILE}" -eq "${NUM_PER_JOB}" ] ; then 
		INDEX_SIMFILE=0
		#echo "reset job" 
	fi
done

DEPENDENCY=afterany
JOBFILES=$APSIM_TEMP/*
INDEX=0
for jobfile in ${JOBFILES}; do
	INDEX=`expr $INDEX + 1`
	SBATCH_COMMANDS="--parsable --job-name=${SBATCH_JOB_NAME}_${INDEX} --time=${TIME} -N 1 -c 40 -o log/apsim_batch-%j" 
	BATCHID=$( sbatch $SBATCH_COMMANDS batch/sbatch_parallel_apsim2.sh $PROJECT_FOLDER $SIM_FOLDER $SINGULARITY_IMAGE $jobfile )
	DEPENDENCY=$DEPENDENCY":"$BATCHID
  	echo "DEPENDENCY: $DEPENDENCY"
done

sbatch --dependency=$DEPENDENCY --job-name=${SBATCH_JOB_NAME}_cleanup --time=01:00:00 -o log/apsim_batch-_cleanup%j batch/sbatch_apsim_batch_cleanup.sh $APSIM_TEMP $SOURCE_FOLDER $OUT_FOLDER

