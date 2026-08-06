#!/bin/bash -x
# Usage: ./start_vnc_test.sh [estimated_time] [partition] [image_name]

set -eu

TIME=${1:-01:00:00}
PARTITION=${2:-compute}
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

# generate a random password and store it in /home/${USER_NAME}/.vnc_config/vnc_password.txt
# this is for testing purposes only, in production the password needs to be set by the user and mounted into the container
mkdir -p "/home/${USER_NAME}/.vnc_config"
PASSWORD_FILE="/home/${USER_NAME}/.vnc_config/vnc_password.txt"
openssl rand -base64 15 | tr -d '\n' > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

VNC_PASSWD_PATH="/home/${USER_NAME}/.vnc_config/encrypted_vnc_passwd"
# create an encrypted password file for vncserver using the generated password
if [ -f "$VNC_PASSWD_PATH" ]; then
    rm -f "$VNC_PASSWD_PATH"
fi 
echo "Creating VNC password file at $VNC_PASSWD_PATH"

singularity exec --cleanenv "${SINGULARITY_IMAGE}" bash -c "echo $(<"$PASSWORD_FILE") | tigervncpasswd -f > \"$VNC_PASSWD_PATH\""
chmod 600 "$VNC_PASSWD_PATH"


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
echo "Password file: /home/${USER_NAME}/.vnc_config/vnc_password.txt"
echo "Stop: scancel ${BATCHID}"
