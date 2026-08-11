#!/bin/bash -x

set -eu

SINGULARITY_IMAGE=ubuntu-26-xfce-vnc.sif
USER_NAME=$(whoami)

VNC_HOME=/home/${USER_NAME}/hpc-vnc
mkdir -p "${VNC_HOME}"
LOGS=${VNC_HOME}/log
mkdir -p "${LOGS}"
USER_SCRATCH=/scratch/${USER_NAME}
VNC_TMPDIR=${USER_SCRATCH}/vnc-temp
mkdir -p "${VNC_TMPDIR}/tmp"
mkdir -p "${VNC_TMPDIR}/run"

# generate a random password and store it in /home/${USER_NAME}/.vnc_config/vnc_password.txt
# this is for testing purposes only, in production the password needs to be set by the user and mounted into the container

mkdir -p "${VNC_HOME}/.config/tigervnc"
PASSWORD_FILE="${VNC_HOME}/vnc_password.txt"
openssl rand -base64 15 | tr -d '\n' > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

VNC_PASSWD_PATH="${VNC_HOME}/.config/tigervnc/passwd"
# create an encrypted password file for vncserver using the generated password
if [ -f "$VNC_PASSWD_PATH" ]; then
    rm -f "$VNC_PASSWD_PATH"
fi 
echo "Creating VNC password file at $VNC_PASSWD_PATH"
export SINGULARITY_HOME=${VNC_HOME}
cd "${VNC_HOME}"

singularity exec --cleanenv  \
    -H "${SINGULARITY_HOME}" \
    -W "${SINGULARITY_HOME}" \ 
    "${SINGULARITY_IMAGE}" \
    bash -c "echo $(<"$PASSWORD_FILE") | vncpasswd -f > \"$VNC_PASSWD_PATH\""


export SINGULARITY_HOME=${VNC_HOME}
cd "${VNC_HOME}"

export SINGULARITYENV_VNC_PORT=5901
export SINGULARITYENV_NO_VNC_PORT=6901
export SINGULARITYENV_VNC_RESOLUTION=1920x1080
export SINGULARITYENV_USER=$(id -un)

singularity exec --cleanenv \
    -B "${VNC_TMPDIR}/run:/run,${VNC_TMPDIR}/tmp:/tmp,${VNC_HOME}/.config/tigervnc/passwd:${VNC_HOME}/.config/tigervnc/passwd" \
    -H "${SINGULARITY_HOME}" \
    -W "${SINGULARITY_HOME}" \
    "${SINGULARITY_IMAGE}" \
    env

echo singularity shell --cleanenv \
    -B "${VNC_TMPDIR}/run:/run,${VNC_TMPDIR}/tmp:/tmp,${VNC_HOME}/.config/tigervnc/passwd:${VNC_HOME}/.config/tigervnc/passwd" \
    -H "${SINGULARITY_HOME}" \
    -W "${SINGULARITY_HOME}" \
    "${SINGULARITY_IMAGE}" 