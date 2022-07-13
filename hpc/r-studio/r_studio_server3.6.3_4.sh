#!/bin/sh -x
#SBATCH --time=08:00:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --output=/home/%u/rstudio-server.job.%j

# from Rocker Project (R for Docker)  

SCRIPT_USER=$1
LOGIN_HOST_NAME=$2
MOUNT_PROJECT=$3
MOUNT_DATA=$4
WORKINGDIR=$5
SINGULARITY_IMAGE=$6
MOUNT_TMP=$7
PROJECT=/project
DATA=/data
TMP=/var/run

export RSTUDIO_SESSION_TIMEOUT='0'
export PASSWORD=$(openssl rand -base64 15)
echo $USER
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:${HOSTNAME}:${PORT} ${SCRIPT_USER}@${LOGIN_HOST_NAME}

   and point your web browser to http://localhost:8787

2. log in to RStudio Server using the following credentials:

   user: ${USER}
   password: ${PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END
R_HOME=/r_home 
# User-installed R packages go into their home directory
if [ ! -e ${WORKINGDIR}/.Renviron ]
then
  printf '\nNOTE: creating '${WORKINGDIR}'/.Renviron file\n\n'
  echo 'R_LIBS_USER='${R_HOME}'/R/%p-library/%v' >> ${WORKINGDIR}/.Renviron
fi
cd ${WORKINGDIR} 
SINGULARITY_HOME=${WORKINGDIR}
export SINGULARITY_HOME
# bind /project directory  
# bind /data directory on the host into the Singularity container.
# By default the only host file systems mounted within the container are $HOME, /tmp, /proc, /sys, and /dev.
singularity exec -B \
    $MOUNT_PROJECT:$PROJECT:ro,$MOUNT_DATA:$DATA:ro,$WORKINGDIR:$R_HOME,$MOUNT_TMP:$TMP \
    $SINGULARITY_IMAGE \
    rserver --www-port ${PORT} --auth-none=0 --auth-pam-helper-path=pam-helper
printf 'rserver exited' 1>&2