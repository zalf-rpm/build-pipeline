#!/bin/bash -x

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --output=/home/%u/loop_task_out.job.%j

NUM_FILES=274
PARALLEL_JOBS=20
CMD='./parallel_run -cores 4 -task '

for  (( INDEX=1; INDEX<=${NUM_FILES}; INDEX++ )) ; do
	${CMD} ${INDEX} &
	if [ `expr ${INDEX} % $PARALLEL_JOBS` -eq 0 ] ; then 
	 wait
	 echo "next batch"
	fi   
done 