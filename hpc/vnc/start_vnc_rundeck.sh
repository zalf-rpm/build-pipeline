#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?host? ?estimated_time? ?partition? ?image_name?

set -eu
[[ $# < 6 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
LOGIN_HOST=$3
TIME=$4
PARTITION=$5
IMAGE_NAME=$6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBATCH_SCRIPT="${SCRIPT_DIR}/sbatch_vnc.sh"

SBATCH_JOB_NAME="vnc_${JOB_EXEC_ID}"
PORT=6901
WORKDIR=/home/${USER}/hpc-vnc
LOGS=${WORKDIR}/log

if [ ! -f "${SBATCH_SCRIPT}" ]; then
    echo "Missing sbatch script: ${SBATCH_SCRIPT}" >&2
    exit 1
fi

if [[ "${IMAGE_NAME}" = /* ]]; then
    SINGULARITY_IMAGE=${IMAGE_NAME}
else
    SINGULARITY_IMAGE=/beegfs/common/singularity/vnc/${IMAGE_NAME}
fi

if [ ! -f "${SINGULARITY_IMAGE}" ]; then
    echo "Image not found: ${SINGULARITY_IMAGE}" >&2
    exit 1
fi

BATCHID=$(squeue --noheader -o "%.18i" -n "${SBATCH_JOB_NAME}" -u "$(whoami)")
if [ -n "${BATCHID}" ]; then
    NODEHOST=$(squeue --noheader -o "%R" -n "${SBATCH_JOB_NAME}" -u "$(whoami)")
    RUN_TIME=$(squeue --noheader -o "%.10M" -n "${SBATCH_JOB_NAME}" -u "$(whoami)")
    TIMELEFT=$(squeue --noheader -o "%.10L" -n "${SBATCH_JOB_NAME}" -u "$(whoami)")
    cat 1>&2 <<END
Job is already running.

Job ID: ${BATCHID}
Node: ${NODEHOST}
Running since: ${RUN_TIME}
Time left: ${TIMELEFT}

SSH tunnel:
ssh -N -L ${PORT}:${NODEHOST}:${PORT} ${USER}@${LOGIN_HOST}

Open:
http://localhost:${PORT}

Password file:
${WORKDIR}/vnc_password.txt

Stop:
scancel ${BATCHID}
END
    exit 0
fi

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

echo "${CMD_LINE_SLURM}"

BATCHID=$(sbatch ${CMD_LINE_SLURM} "${SBATCH_SCRIPT}")
LOG_NAME=${LOGS}/vnc_${DATE}_${BATCHID}.log

COUNTER=0
while [ ! -f "${LOG_NAME}" ] && [ ! "${COUNTER}" -eq 30 ]; do
    sleep 10
    COUNTER=$((COUNTER + 1))
    if [ "${COUNTER}" -eq 30 ]; then
        scancel "${BATCHID}"
        echo "timeout: no free slot available. Try again later"
        exit 1
    fi
done

sleep 5
NODEHOST=$(squeue -j "${BATCHID}" --noheader --format="%R")

cat 1>&2 <<END
1. SSH tunnel from your workstation:

   ssh -N -L ${PORT}:${NODEHOST}:${PORT} ${USER}@${LOGIN_HOST}

2. Open in browser:

   http://localhost:${PORT}

3. Use password from:

   ${WORKDIR}/vnc_password.txt

4. Stop when done:

   scancel ${BATCHID}
END
