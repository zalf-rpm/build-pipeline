#!/bin/bash +x 
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --partition=compute
#SBATCH --job-name=make_files_job
#SBATCH --time=00:05:00
#SBATCH --array=0-2
#SBATCH -o make_files_job-%j.log

# create a file for each array task


# batch file containing list of arguments for each array task
FILENAME=$1
# take the rest of the arguments as array job arguments
ARGS=("${@:2}") 

# check if the number of arguments matches the array range
if [ ${#ARGS[@]} -ne 3 ]; then
    echo "Error: Number of arguments (${#ARGS[@]}) does not match array range (3)."
    exit 1
fi
# create a file named based on the argument for this array task
echo "This is file ${ARGS[$SLURM_ARRAY_TASK_ID]}" > ${FILENAME}_${ARGS[$SLURM_ARRAY_TASK_ID]}.txt


# example usage:
# sbatch array_job_test.sh output_file arg1 arg2 arg3
# This will create files: output_file_arg1.txt, output_file_arg2.txt, output_file_arg3.txt