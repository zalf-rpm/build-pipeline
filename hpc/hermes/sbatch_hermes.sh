#!/bin/bash +x 
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --partition=compute

MOUNT_PROJECT=$1
MOUNT_DATA=$2
MOUNT_OUTPUT=$3
IMAGE_PATH=$4
BATCH_LIST_FILE=$5
# take the rest of the arguments as the arguments to the hermes2go command
ARGS=("${@:6}")

PROJECT=/project
DATA=/project/weather
OUTPUT=/project/out
CMDLINE="hermes2go -module batch -concurrent 70 -batch ${BATCH_LIST_FILE} -lines"

cmd="srun singularity run -B \
$MOUNT_PROJECT:$PROJECT,\
$MOUNT_DATA:$DATA,\
$MOUNT_OUTPUT:$OUTPUT \
--pwd ${PROJECT} \
${IMAGE_PATH} \
$CMDLINE ${ARGS[$SLURM_ARRAY_TASK_ID]}"

echo $cmd
$cmd