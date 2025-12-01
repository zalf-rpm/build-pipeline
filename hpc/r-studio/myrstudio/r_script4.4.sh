#!/bin/sh -x
#SBATCH --time=08:00:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --output=/home/%u/rscript.job.%j

# from Rocker Project (R for Docker)  

SCRIPT_USER=$1
MOUNT_PROJECT=$2
MOUNT_DATA=$3
HOMEDIR=$4
SINGULARITY_IMAGE=$5
MOUNT_DATA_SOURCE1=$6
MOUNT_DATA_SOURCE2=$7
MOUNT_DATA_SOURCE3=$8
READ_ONLY_SOURCES=${9}
SCRIPT_FILE=${10}
# all other arguments are passed to the script
SCRIPT_ARGS=${@:11}

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
ENV_VARS=OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE},R_LIBS_USER=${HOMEDIR}/R/rocker-rstudio/4.4
export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"


# bind /project directory  
# bind /data directory on the host into the Singularity container.
# By default the only host file systems mounted within the container are $HOME, /tmp, /proc, /sys, and /dev.
singularity run --cleanenv \
--env ${ENV_VARS} \
-B $MOUNT_PROJECT:$PROJECT,$MOUNT_DATA:$DATA:ro,$MOUNT_CLUSTERHOME:${CLUSTERHOME}${MOUNT_DATA_SOURCES} \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
Rscript $SCRIPT_FILE $SCRIPT_ARGS