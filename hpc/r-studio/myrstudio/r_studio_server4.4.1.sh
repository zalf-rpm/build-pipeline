#!/bin/sh 
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
MOUNT_DATA_SOURCE1=$7
MOUNT_DATA_SOURCE2=$8
MOUNT_DATA_SOURCE3=$9
READ_ONLY_SOURCES=${10}


# read password from file
TRANS=${HOMEDIR}/.rundeck/r_trans.yml
# check if setup file exists
if [ ! -f ${TRANS} ] ; then
    echo "setup file not found"
    exit 1
fi
# get the second argument from the setup file
PASSW=$( cat $TRANS )

# strip leading and trailing whitespaces
PASSW=$( echo $PASSW | xargs )

# remove setup file 
rm -f $TRANS

# fail if no password is given
if [ -z "$PASSW" ] ; then
    echo "No password given"
    exit 1
fi

PROJECT=/project
DATA=/data
CLUSTERHOME=/myhome
MOUNT_CLUSTERHOME=/home/$SCRIPT_USER

# if MOUNT_DATA_SOURCEx is not none, add to MOUNT_DATA_SOURCES
# if read_only_sources is true, mount data sources as read-only
MOUNT_DATA_SOURCES=""
if [ $MOUNT_DATA_SOURCE1 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE1:$MOUNT_DATA_SOURCE1"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE2 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE2:$MOUNT_DATA_SOURCE2"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi
if [ $MOUNT_DATA_SOURCE3 != "none" ] ; then
  MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES,$MOUNT_DATA_SOURCE3:$MOUNT_DATA_SOURCE3"
  if [ $READ_ONLY_SOURCES == "true" ] ; then
    MOUNT_DATA_SOURCES="$MOUNT_DATA_SOURCES:ro"
  fi
fi


export SINGULARITY_HOME=${HOMEDIR}

cd ${HOMEDIR}
# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
TMPDIR=${HOMEDIR}/tmp
mkdir -p ${TMPDIR}
workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp(dir="'${TMPDIR}'"))')
mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server
cat > ${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# clean up at end of script
function clean_up {
    # remove temporary directory
    rm -rf "${TMPDIR:?}"
    exit
}

# Always call "clean_up" when script ends
# This even executes on job failure/cancellation
trap 'clean_up' EXIT

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment


cat > ${workdir}/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
export R_LIBS_USER=${HOMEDIR}/R/rocker-rstudio/4.4
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x ${workdir}/rsession.sh

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/rsession.sh:/etc/rstudio/rsession.sh,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"

export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT='0'
export SINGULARITYENV_PASSWORD=$PASSW
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
   password: your selected password 
When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

# bind /project directory  
# bind /data directory on the host into the Singularity container.
# By default the only host file systems mounted within the container are $HOME, /tmp, /proc, /sys, and /dev.
singularity exec --cleanenv \
-B $MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_CLUSTERHOME:${CLUSTERHOME}${MOUNT_DATA_SOURCES} \
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