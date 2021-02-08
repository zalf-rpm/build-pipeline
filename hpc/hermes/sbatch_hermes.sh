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
NUM_NODES=$6

EXECUTABLE=hermes2go
PROJECT=/project
DATA=/data
OUTPUT=/out

ARGS=($(`singularity run -B ${MOUNT_PROJECT}:${PROJECT} ${IMAGE_PATH} calcHermesBatch -list ${NUM_NODES} ${BATCH_LIST_PATH}`))
echo $ARGS


CMDLINE="-module batch -concurrent 70 -batch ${BATCH_LIST_FILE} -lines"

CMD="srun singularity run -B \
$MOUNT_PROJECT:$PROJECT,\
$MOUNT_DATA:$DATA,\
$MOUNT_OUTPUT:$OUTPUT \
--pwd ${PROJECT} \
${SINGULARITY_IMAGE}"

srun ${CMD} $EXECUTABLE $CMDLINE ${ARGS[$SLURM_ARRAY_TASK_ID]}
