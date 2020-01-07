#!/bin/bash
set -eu

MOUNT_STORAGE=$1 		#/beegfs/rpm/projects/apsim/projects/munir_hoffmann_sim/Data_Crop_Rotation
SIM_FOLDER=$2 		    #apsimfiles
SINGULARITY_IMAGE=$3 	#/home/rpm/singularity/apsim/apsim-classic_79.1.sif
JOB_FILENAME=$4 		#~/apsim_run/jobfile1.txt
PARALLEL_JOBS=40

WORKDIR=/storage/apsim

export LD_LIBRARY_PATH=/apsim/Temp/Model
export MAX_APSIM_OUTPUT_LINES=100

CMD="singularity run -B \
$MOUNT_STORAGE:$WORKDIR \
--pwd /apsim/Temp/Model ${SINGULARITY_IMAGE} Apsim.exe "

# Execute x jobs in parallel
INDEX=0
while read file; do
	INDEX=`expr $INDEX + 1`
	${CMD} ${WORKDIR}/${SIM_FOLDER}/${file} &
	if [ `expr ${INDEX} % $PARALLEL_JOBS` -eq 0 ] ; then 
	 wait
	 echo "next batch"
	fi   
done <${JOB_FILENAME}

wait

