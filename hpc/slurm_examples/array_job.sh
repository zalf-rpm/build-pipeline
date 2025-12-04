#!/bin/bash +x 
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --partition=compute
#SBATCH --job-name=my_array_job
#SBATCH --time=02:00:00
#SBATCH --array=0-9
#SBATCH -o /path/to/logs/my_array_job-%j.out

# batch file containing list of arguments for each array task
BATCH_LIST_FILE=$1
# take the rest of the arguments as array job arguments
ARGS=("${@:2}") 

# a program that takes a batch file and lines argument, to select the line based on SLURM_ARRAY_TASK_ID
MY_PROGRAM="my_program"
# Construct the command line
CMDLINE="${MY_PROGRAM} -batch ${BATCH_LIST_FILE} -lines ${ARGS[$SLURM_ARRAY_TASK_ID]}"
echo $CMDLINE
# Execute the command
$CMDLINE

# example usage:
# sbatch array_job.sh /path/to/batch_list.txt 1-2 3-4 5-6 7-8 9-10 11-12 13-14 15-16 17-18 19-20
# make sure the number of lines in batch_list.txt matches the array range (0-9 here)