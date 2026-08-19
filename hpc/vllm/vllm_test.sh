#!/bin/bash -x

DEVICE=${1:-0}
PORT=${2:-8000}
SINGULARITY_IMAGE=${3:-/beegfs/common/singularity/vllm/vllm-openai.v0.26.0-cu129-ubuntu2404.sif}

HOMEDIR=/beegfs/$USER/hpc-vllm
WORKDIR=${HOMEDIR}/workdir

mkdir -p ${HOMEDIR}
mkdir -p ${WORKDIR}/run
mkdir -p ${WORKDIR}/tmp
mkdir -p ${HOMEDIR}/.cache/huggingface

set +x
HF_TOKEN=$(cat /home/$USER/huggingface_access/token.txt)

export SINGULARITY_HOME=${HOMEDIR}
export SINGULARITY_BINDPATH="${WORKDIR}/run:/run,${WORKDIR}/tmp:/tmp,${HOMEDIR}/.cache/huggingface:/root/.cache/huggingface"

export SINGULARITYENV_CUDA_VISIBLE_DEVICES=$DEVICE
export SINGULARITYENV_VLLM_ENABLE_CUDA_COMPATIBILITY=1
export SINGULARITYENV_HF_TOKEN=$HF_TOKEN
set -x

cd ${HOMEDIR}
singularity exec --cleanenv --nv \
    -H ${HOMEDIR} \
    -W ${HOMEDIR} \
    $SINGULARITY_IMAGE \
    vllm serve Qwen/Qwen3-Coder-Next --port $PORT

