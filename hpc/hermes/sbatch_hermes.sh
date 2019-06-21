#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --partition=compute

MOUNT_PROJECT=$1
MOUNT_DATA=$2
MOUNT_OUTPUT=$1
IMAGE_PATH=$2
BATCH_LIST_FILE=$3
ARGS=$4

EXECUTABLE=hermestogo
EXECUTABLE_DIR=/hermes/go
PROJECT=/hermes/project
DATA=/hermes/data
OUTPUT=/hermes/out
CMDLINE="-module batch -concurrent 40 -logoutput -batch $PROJECTDATA/${BATCH_LIST_FILE} -lines"

CMD="srun singularity run -B \
$MOUNT_PROJECT:$PROJECTDATA,\
$MOUNT_DATA:$DATA,\
$MOUNT_OUTPUT:$OUTPUT \
--pwd ${EXECUTABLE_DIR} \
${SINGULARITY_IMAGE}"

${CMD} $EXECUTABLE $CMDLINE ${ARGS[$SLURM_ARRAY_TASK_ID]}
