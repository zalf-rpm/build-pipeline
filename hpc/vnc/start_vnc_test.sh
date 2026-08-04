#!/bin/bash -x
# Usage: ./start_vnc_test.sh [estimated_time] [partition] [image_name]

set -eu

TIME=${1:-08:00:00}
PARTITION=${2:-gpu}
IMAGE_NAME=${3:-ubuntu-26-xfce-vnc.sif}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBATCH_SCRIPT="${SCRIPT_DIR}/sbatch_vnc.sh"
USER_NAME=$(whoami)

WORKDIR=/home/${USER_NAME}/hpc-vnc
LOGS=${WORKDIR}/log
SBATCH_JOB_NAME="vnc_test_${USER_NAME}"

if [[ "${IMAGE_NAME}" = /* ]]; then
    SINGULARITY_IMAGE=${IMAGE_NAME}
else
    SINGULARITY_IMAGE=/beegfs/common/singularity/vnc/${IMAGE_NAME}
fi

if [ ! -f "${SBATCH_SCRIPT}" ]; then
    echo "Missing sbatch script: ${SBATCH_SCRIPT}" >&2
    exit 1
fi

if [ ! -f "${SINGULARITY_IMAGE}" ]; then
    echo "Image not found: ${SINGULARITY_IMAGE}" >&2
    exit 1
fi

HPC_PARTITION="--partition=compute"
CORES=80
if [ "${PARTITION}" = "highmem" ]; then
    HPC_PARTITION="--partition=highmem"
    CORES=80
elif [ "${PARTITION}" = "gpu" ]; then
    HPC_PARTITION="--partition=gpu"
    CORES=48
elif [ "${PARTITION}" = "fat" ]; then
    HPC_PARTITION="--partition=fat"
    CORES=160
fi

mkdir -p "${WORKDIR}" "${LOGS}"
cd "${WORKDIR}"

DATE=$(date +%Y-%d-%B_%H%M%S)
CMD_LINE_SLURM="--parsable --job-name=${SBATCH_JOB_NAME} ${HPC_PARTITION} --exclusive --time=${TIME} -N 1 -c ${CORES} --export=ALL,SINGULARITY_IMAGE=${SINGULARITY_IMAGE} -o ${LOGS}/vnc_${DATE}_%j.log"

echo "Submitting with: ${CMD_LINE_SLURM}"
BATCHID=$(sbatch ${CMD_LINE_SLURM} "${SBATCH_SCRIPT}")

echo "Job submitted: ${BATCHID}"
echo "Wait until job is running, then check node with:"
echo "squeue -j ${BATCHID}"
echo ""
echo "After node is known, tunnel from workstation:"
echo "ssh -N -L 6901:<nodehost>:6901 ${USER_NAME}@login02.cluster.zalf.de"
echo ""
echo "Open: http://localhost:6901"
echo "Password file: ${WORKDIR}/vnc_password.txt"
echo "Stop: scancel ${BATCHID}"
