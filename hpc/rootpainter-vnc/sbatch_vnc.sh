#!/bin/bash
#SBATCH --job-name='vnc-web'
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=08:10:00

SINGULARITY_IMAGE=/beegfs/common/singularity/vnc/ubuntu-22-xfce-vnc-gpu.sif
HOMEDIR=/home/${USER}/vnchome
MOUNT_PROJECT=/beegfs/${USER}
PROJECT=/beegfs/${USER}
VNC_TMPDIR=/home/${USER}/.vnctmp/${SLURM_JOB_ID:?}
SUBMIT_DIR="${SLURM_SUBMIT_DIR:?}"

export VNC_ACCESS_PW=$(openssl rand -base64 15)

mkdir -p $VNC_TMPDIR
mkdir -p $HOMEDIR

function clean_up {
    # Leave ${HOMEDIR}
    cd "${SUBMIT_DIR:?}" || exit
    # Use :? to only remove if the variable is defined. Otherwise exit
    rm -rf "${VNC_TMPDIR:?}"
    # Remove password file
    rm -f ${SUBMIT_DIR}/vnc_password.txt
    exit
}

# Always call "clean_up" when script ends
# This even executes on job failure/cancellation
trap 'clean_up' EXIT

# print password to file
if [ -f ${SUBMIT_DIR}/vnc_password.txt ]; then
    rm -f ${SUBMIT_DIR}/vnc_password.txt
fi
echo $VNC_ACCESS_PW > ${SUBMIT_DIR}/vnc_password.txt

export SINGULARITY_HOME=${HOMEDIR}
cd ${HOMEDIR}

ENV_VARS=VNC_PORT=5901,VNC_PW=${VNC_ACCESS_PW},NO_VNC_PORT=6901,VNC_RESOLUTION=1600x900
# Bind the temporary directory to /tmp
export SINGULARITY_BIND="${VNC_TMPDIR}:/tmp"

singularity exec --nv --cleanenv \
--env ${ENV_VARS} \
-B $MOUNT_PROJECT:$PROJECT \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
 /opt/vnc_startup-ubuntu-22.sh 