#!/bin/bash
set -eu

MOUNT_STORAGE=$1 		#/beegfs/rpm/projects/apsim/projects/munir_hoffmann_sim/Data_Crop_Rotation
MOUNT_CLIMATE=$2		#/beegfs/rpm/projects/apsim/projects/some/climate/folder
SIM_FOLDER=$3 		    #apsimfiles
SINGULARITY_IMAGE=$4 	#/home/rpm/singularity/apsim/apsim-classic_79.1.sif
JOB_FILENAME=$5			#~/apsim_run/jobfile1.txt
PARALLEL_JOBS=40

WORKDIR=/storage/apsim
CLIMATEDIR=/met

export LD_LIBRARY_PATH=/apsim/Temp/Model
export MAX_APSIM_OUTPUT_LINES=100

CMD="singularity run -B \
$MOUNT_STORAGE:$WORKDIR,\
$MOUNT_CLIMATE:$CLIMATEDIR \
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

