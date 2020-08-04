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


DATE=`date +%Y-%d-%B_%H%M%S`
JOB=$( basename ${JOB_FILENAME} )
TEMPWORKFOLDER=${SIM_FOLDER}_"${JOB%.*}"_TEMP_$DATE
mkdir $MOUNT_STORAGE/$TEMPWORKFOLDER

CMD="singularity run -B \
$MOUNT_STORAGE:$WORKDIR,\
$MOUNT_CLIMATE:$CLIMATEDIR \
--pwd /apsim/Temp/Model ${SINGULARITY_IMAGE} Apsim.exe "

~/batch/copyinlargedir/copydirs -src=$MOUNT_STORAGE/${SIM_FOLDER} -dst=$MOUNT_STORAGE/$TEMPWORKFOLDER

NUMDEFAULTS=$( ls $MOUNT_STORAGE/$TEMPWORKFOLDER | wc -l )

LINE=${CMD}
# Execute x jobs in parallel
INDEX=0
SIMS=" "
while read file; do
	INDEX=`expr $INDEX + 1`
	LINE="${LINE} ${WORKDIR}/${TEMPWORKFOLDER}/${file}"
	name="${file%.*}"
	SIMS=$SIMS" -sim "$name
	mv $MOUNT_STORAGE/${SIM_FOLDER}/${file} $MOUNT_STORAGE/$TEMPWORKFOLDER/
	if [ `expr ${INDEX} % $PARALLEL_JOBS` -eq 0 ] ; then 
	 	DATE=`date +%Y-%d-%B_%H%M%S`
	 	echo ${DATE} ">" $LINE
	 	$LINE 
	 	DATE=`date +%Y-%d-%B_%H%M%S`
	 	echo ${DATE} "move *.out and *.sum "
	 	~/batch/apsimmoveoutput/apsimoutput -source $MOUNT_STORAGE/${TEMPWORKFOLDER} -out ${APSIM_OUT_FOLDER} $SIMS 
		echo ${DATE} "next batch"
	 	LINE=${CMD}
	 	SIMS=" "
		mv $MOUNT_STORAGE/$TEMPWORKFOLDER/*.apsim $MOUNT_STORAGE/${SIM_FOLDER}/
	fi   
done <${JOB_FILENAME}

wait

if [ `expr ${INDEX} % $PARALLEL_JOBS` -ne 0 ] ; then 
	DATE=`date +%Y-%d-%B_%H%M%S`
	echo ${DATE} ">" $LINE
	$LINE 
	DATE=`date +%Y-%d-%B_%H%M%S`
	echo ${DATE} "move *.out and *.sum "
	~/batch/apsimmoveoutput/apsimoutput -source $MOUNT_STORAGE/${TEMPWORKFOLDER} -out ${APSIM_OUT_FOLDER} $SIMS
	mv $MOUNT_STORAGE/$TEMPWORKFOLDER/*.apsim $MOUNT_STORAGE/${SIM_FOLDER}/
fi  

DATE=`date +%Y-%d-%B_%H%M%S`
echo ${DATE} "done"

#check if folder is empty except for default files
CURRFILES=$( ls $MOUNT_STORAGE/$TEMPWORKFOLDER | wc -l )
echo "current Files $CURRFILES default $NUMDEFAULTS"
if [ $CURRFILES == $NUMDEFAULTS ] ; then 
	chmod -R u+w $MOUNT_STORAGE/$TEMPWORKFOLDER
	rm -r $MOUNT_STORAGE/$TEMPWORKFOLDER
fi