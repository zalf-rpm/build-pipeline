#!/bin/bash
set -eu

MOUNT_STORAGE=$1 		#/beegfs/rpm/projects/apsim/projects/munir_hoffmann_sim/Data_Crop_Rotation
MOUNT_CLIMATE=$2		#/beegfs/rpm/projects/apsim/projects/some/climate/folder
SIM_FOLDER=$3 		    #apsimfiles
SINGULARITY_IMAGE=$4 	#/home/rpm/singularity/apsim/apsim-classic_79.1.sif
JOB_FILENAME=$5			#~/apsim_run/jobfile1.txt
APSIM_OUT_FOLDER=$6 	# out folder
PARALLEL_JOBS=40

WORKDIR=/storage/apsim
CLIMATEDIR=/met

export LD_LIBRARY_PATH=/apsim/Temp/Model
export MAX_APSIM_OUTPUT_LINES=100

CMD="singularity run -B \
$MOUNT_STORAGE:$WORKDIR,\
$MOUNT_CLIMATE:$CLIMATEDIR \
--pwd /apsim/Temp/Model ${SINGULARITY_IMAGE} Apsim.exe "

EXECUTEFOLDER=`pwd`

LINE=${CMD}
# Execute x jobs in parallel
INDEX=0
ARRAY=" "
while read file; do
	INDEX=`expr $INDEX + 1`
	LINE="${LINE} ${WORKDIR}/${SIM_FOLDER}/${file}"
	name="${file%.*}"
	ARRAY=$ARRAY" -sim "$name
	if [ `expr ${INDEX} % $PARALLEL_JOBS` -eq 0 ] ; then 
	 	DATE=`date +%Y-%d-%B_%H%M%S`
	 	echo ${DATE} ">" $LINE
	 	$LINE 
	 	DATE=`date +%Y-%d-%B_%H%M%S`
	 	echo ${DATE} "move *.out and *.sum "
	 	~/batch/apsimmoveoutput/apsimoutput -source $MOUNT_STORAGE/${SIM_FOLDER} -out ${APSIM_OUT_FOLDER} $ARRAY &
		echo ${DATE} "next batch"
	 	LINE=${CMD}
	 	ARRAY=" "
	fi   
done <${JOB_FILENAME}

wait

if [ -neq $LINE ${CMD} ] ; then 
	DATE=`date +%Y-%d-%B_%H%M%S`
	echo ${DATE} ">" $LINE
	$LINE 
	DATE=`date +%Y-%d-%B_%H%M%S`
	echo ${DATE} "move *.out and *.sum "
	~/batch/apsimmoveoutput/apsimoutput -source $MOUNT_STORAGE/${SIM_FOLDER} -out ${APSIM_OUT_FOLDER} $ARRAY
fi  

DATE=`date +%Y-%d-%B_%H%M%S`
echo ${DATE} "done"