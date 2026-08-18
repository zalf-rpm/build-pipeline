#!/bin/bash -x

HOMEDIR=$1
MODEL_DIR=$2
LOG_DIR=$3
SINGULARITY_IMAGE=$4
TOKEN_DIR=$5

MODEL_TAB_AUTO_COMPLETE="qwen3-coder-next"
MODEL_CODING_CHAT="glm-5.2"
MODEL_AGENT="mistral-7b-instruct-v0.1"
MODEL_PLANNING="mistral-7b-instruct-v0.1"


cd ${HOMEDIR}

DATE=`date +%Y-%d-%B_%H%M%S`

# Create temporary directory to be populated with directories to bind-mount in the container
# create it on /scratch to avoid permission and cleanup issues with /tmp
TMPDIR=/scratch/${USER}_tmp_${DATE}
mkdir -p ${TMPDIR}
WORKDIR=$(python -c 'import tempfile; print(tempfile.mkdtemp(dir="'${TMPDIR}'"))')
mkdir -p -m 700 ${WORKDIR}/run ${WORKDIR}/tmp ${WORKDIR}/vllm

# clean up at end of script
function clean_up {
    # remove WORKDIR directory
    rm -rf "${WORKDIR:?}"
    exit
}

# Always call "clean_up" when script ends
# This even executes on job failure/cancellation
trap 'clean_up' EXIT


export SINGULARITY_HOME=${HOMEDIR}
export SINGULARITY_BINDPATH="${WORKDIR}/run:/run,${WORKDIR}/tmp:/tmp,${WORKDIR}/vllm:/home/vllm,${MODEL_DIR}:/home/vllm/.cache/huggingface,${TOKEN_DIR}:/huggingface_token"

singularity exec --cleanenv \
--nv \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
sh start_vllm.sh 0 ${MODEL_TAB_AUTO_COMPLETE} 2>&1 | tee ${LOG_DIR}/vllm_tab_auto_complete_${DATE}.log &

singularity exec --cleanenv \
--nv \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
sh start_vllm.sh 1 ${MODEL_CODING_CHAT} 2>&1 | tee ${LOG_DIR}/vllm_coding_chat_${DATE}.log &

singularity exec --cleanenv \
--nv \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
sh start_vllm.sh 2 ${MODEL_AGENT} 2>&1 | tee ${LOG_DIR}/vllm_agent_${DATE}.log &

singularity exec --cleanenv \
--nv \
-H $SINGULARITY_HOME \
-W $SINGULARITY_HOME $SINGULARITY_IMAGE \
sh start_vllm.sh 3 ${MODEL_PLANNING} 2>&1 | tee ${LOG_DIR}/vllm_planning_${DATE}.log &

wait
printf 'vllm exited' 1>&2
