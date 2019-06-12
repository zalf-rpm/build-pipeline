#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

MOUNT_STORAGE=$1
SINGULARITY_IMAGE=$2
JOB_NAME=$3

WORKDIR=/storage/apsim

export LD_LIBRARY_PATH=/apsim/Temp/Model

CMD="srun singularity run -B \
$MOUNT_STORAGE:$WORKDIR \
--pwd /apsim/Temp/Model
${SINGULARITY_IMAGE} "

shift 3
${CMD} Apsim.exe $@

