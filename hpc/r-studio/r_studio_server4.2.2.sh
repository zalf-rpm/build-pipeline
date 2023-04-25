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
HOMEDIR=$5
SINGULARITY_IMAGE=$6
#MOUNT_TMP=$7
PROJECT=/project
DATA=/data


export SINGULARITY_HOME=${HOMEDIR}

cd ${HOMEDIR}
# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp())')
mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server
cat > ${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment


cat > ${workdir}/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
export R_LIBS_USER=${HOMEDIR}/R/rocker-rstudio/4.2
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x ${workdir}/rsession.sh

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/rsession.sh:/etc/rstudio/rsession.sh,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"

export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT='0'
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)
export SINGULARITYENV_USER=$(id -un)

# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
cat 1>&2 <<END

1. SSH tunnel from your workstation using the following command:

   ssh -N -L 8787:${HOSTNAME}:${PORT} ${SCRIPT_USER}@${LOGIN_HOST_NAME}

   and point your web browser to http://localhost:8787

2. log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

# bind /project directory  
# bind /data directory on the host into the Singularity container.
# By default the only host file systems mounted within the container are $HOME, /tmp, /proc, /sys, and /dev.
singularity exec --cleanenv \
-B $MOUNT_PROJECT:$PROJECT:ro,$MOUNT_DATA:$DATA:ro \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
rserver --www-port ${PORT} \
 --server-user $SINGULARITYENV_USER \
 --auth-none=0 \
 --auth-pam-helper-path=pam-helper \
 --auth-stay-signed-in-days=30 \
 --auth-timeout-minutes=0 \
 --rsession-path=/etc/rstudio/rsession.sh 
printf 'rserver exited' 1>&2