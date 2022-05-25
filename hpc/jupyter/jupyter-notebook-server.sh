#!/bin/sh -x
#SBATCH --time=00:015:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --output=/home/%u/jupyter-server.job.%j


LOGIN_HOST_NAME=login01.cluster.zalf.de
SINGULARITY_IMAGE=~/singularity/jupyter/scipy-notebook_lab-3.4.2.sif

export PASSWORD=$(openssl rand -base64 15)
export USE_HTTPS=yes
#export SINGULARITYENV_USER=$(id -un)
PORT=8888

cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8888:${HOSTNAME}:${PORT} ${USER}@${LOGIN_HOST_NAME}

   and point your web browser to http://localhost:8888

2. log in to Server using the following credentials:

   user: ${USER}
   password: ${PASSWORD}

END

singularity run $SINGULARITY_IMAGE 

printf 'jupyter exited' 1>&2