#!/bin/bash
#SBATCH --job-name='vnc-web'
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=08:00:00

set -euo pipefail

SINGULARITY_IMAGE=${SINGULARITY_IMAGE:-/beegfs/common/singularity/vnc/ubuntu-26-xfce-vnc.sif}
VNC_HOME=/home/${USER}/hpc-vnc
MYHOME_SOURCE=/home/${USER}
BEEGFS_USER_SOURCE=/beegfs/${USER}
BEEGFS_COMMON_SOURCE=/beegfs/common
OPTIONAL_DATA01_SOURCE=/data01/PB/${USER}
VNC_TMPDIR=/scratch/${USER}/vnc-temp
SUBMIT_DIR=${SLURM_SUBMIT_DIR:-$PWD}

if ! command -v singularity >/dev/null 2>&1; then
    echo "singularity command not found" >&2
    exit 1
fi

if [ ! -f "${SINGULARITY_IMAGE}" ]; then
    echo "Image not found: ${SINGULARITY_IMAGE}" >&2
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl command not found" >&2
    exit 1
fi

export VNC_ACCESS_PW
VNC_ACCESS_PW=$(openssl rand -base64 15 | tr -d '\n')

mkdir -p "${VNC_TMPDIR}"
mkdir -p "${VNC_HOME}"

clean_up() {
    cd "${SUBMIT_DIR}" || true
    rm -rf "${VNC_TMPDIR:?}"
    rm -f "${SUBMIT_DIR}/vnc_password.txt"
}

trap clean_up EXIT INT TERM

printf '%s\n' "${VNC_ACCESS_PW}" > "${SUBMIT_DIR}/vnc_password.txt"

export SINGULARITY_HOME=${VNC_HOME}
cd "${VNC_HOME}"

ENV_VARS="VNC_PORT=5901,VNC_PW=${VNC_ACCESS_PW},NO_VNC_PORT=6901,VNC_RESOLUTION=1920x1080"
BINDS="${MYHOME_SOURCE}:/myhome,${BEEGFS_USER_SOURCE}:${BEEGFS_USER_SOURCE},${BEEGFS_COMMON_SOURCE}:/beegfs/common,${VNC_TMPDIR}:/tmp"

if [ -d "${OPTIONAL_DATA01_SOURCE}" ]; then
    BINDS="${BINDS},${OPTIONAL_DATA01_SOURCE}:${OPTIONAL_DATA01_SOURCE}"
fi

singularity exec --nv --cleanenv \
    --env "${ENV_VARS}" \
    -B "${BINDS}" \
    -H "${SINGULARITY_HOME}" \
    -W "${SINGULARITY_HOME}" \
    "${SINGULARITY_IMAGE}" \
    /opt/vnc_startup-ubuntu-26.sh
