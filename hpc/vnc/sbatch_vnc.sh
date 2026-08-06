#!/bin/bash 
#SBATCH --job-name='vnc-web'
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=01:00:00

set -euxo pipefail

SINGULARITY_IMAGE=${SINGULARITY_IMAGE:-/beegfs/common/singularity/vnc/ubuntu-26-xfce-vnc.sif}
VNC_HOME=/home/${USER}/hpc-vnc
MYHOME_SOURCE=/home/${USER}
BEEGFS_USER_SOURCE=/beegfs/${USER}
BEEGFS_COMMON_SOURCE=/beegfs/common
OPTIONAL_DATA01_SOURCE=/data01/FDS/${USER}
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

mkdir -p "${VNC_TMPDIR}/tmp"
mkdir -p "${VNC_HOME}"
mkdir -p "${VNC_TMPDIR}/run"
mkdir -p "${VNC_HOME}/.config/tigervnc"

clean_up() {
    cd "${SUBMIT_DIR}" || true
    rm -rf "${VNC_TMPDIR:?}"
}

trap clean_up EXIT INT TERM


export SINGULARITY_HOME=${VNC_HOME}
cd "${VNC_HOME}"

# user folder bindings
BINDS="${MYHOME_SOURCE}:/myhome,${BEEGFS_USER_SOURCE}:${BEEGFS_USER_SOURCE},${BEEGFS_COMMON_SOURCE}:/beegfs/common"
# system bindings
export SINGULARITY_BIND="${VNC_TMPDIR}/run:/run,${VNC_TMPDIR}/tmp:/tmp,/home/${USER}/.vnc_config/encrypted_vnc_passwd:${VNC_HOME}/.config/tigervnc/passwd"

export SINGULARITYENV_VNC_PORT=5901
export SINGULARITYENV_NO_VNC_PORT=6901
export SINGULARITYENV_VNC_RESOLUTION=1920x1080
export SINGULARITYENV_USER=$(id -un)

if [ -d "${OPTIONAL_DATA01_SOURCE}" ]; then
    BINDS="${BINDS},${OPTIONAL_DATA01_SOURCE}:${OPTIONAL_DATA01_SOURCE}"
fi

singularity exec --cleanenv \
    -B "${BINDS}" \
    -H "${SINGULARITY_HOME}" \
    -W "${SINGULARITY_HOME}" \
    "${SINGULARITY_IMAGE}" \
    /opt/vnc_startup-ubuntu-26.sh
