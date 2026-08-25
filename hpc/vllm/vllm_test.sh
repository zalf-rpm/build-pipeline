#!/bin/bash -x

DEVICE=${1:-0,1}
PORT=${2:-8000}
SINGULARITY_IMAGE=${3:-/beegfs/common/singularity/vllm/vllm-openai.v0.26.0-cu129-ubuntu2404.sif}

HOMEDIR=/beegfs/$USER/hpc-vllm
WORKDIR=${HOMEDIR}/workdir

mkdir -p ${HOMEDIR}
mkdir -p ${WORKDIR}/run
mkdir -p ${WORKDIR}/tmp
mkdir -p ${HOMEDIR}/.cache/huggingface

# JIT/compile caches produce many small files; keep them on local scratch, not BeeGFS
USER_SCRATCH=/scratch/$USER
mkdir -p ${USER_SCRATCH}
LOCAL_CACHE=${USER_SCRATCH}/hpc-vllm-cache
mkdir -p ${LOCAL_CACHE}/vllm ${LOCAL_CACHE}/flashinfer ${LOCAL_CACHE}/torchinductor

# cleanup users scratch on exit
trap "rm -rf ${USER_SCRATCH}" EXIT

set +x
HF_TOKEN=$(cat /home/$USER/huggingface_access/token.txt)

export SINGULARITY_HOME=${HOMEDIR}
export SINGULARITY_BINDPATH="${WORKDIR}/run:/run,${WORKDIR}/tmp:/tmp,${HOMEDIR}/.cache/huggingface:/root/.cache/huggingface,${LOCAL_CACHE}/vllm:/root/.cache/vllm,${LOCAL_CACHE}/flashinfer:/root/.cache/flashinfer"

export SINGULARITYENV_CUDA_VISIBLE_DEVICES=$DEVICE
export SINGULARITYENV_VLLM_ENABLE_CUDA_COMPATIBILITY=1
export SINGULARITYENV_HF_TOKEN=$HF_TOKEN
export SINGULARITYENV_NCCL_NET=Socket
export SINGULARITYENV_NCCL_IB_DISABLE=1
export SINGULARITYENV_NCCL_NET_PLUGIN=none
export SINGULARITYENV_TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor
export SINGULARITYENV_OMP_NUM_THREADS=16
set -x

cd ${HOMEDIR}
singularity exec --cleanenv --nv \
    -H ${HOMEDIR} \
    -W ${HOMEDIR} \
    $SINGULARITY_IMAGE \
    vllm serve Qwen/Qwen3-Coder-Next \
    --port $PORT \
    --tensor-parallel-size 2 \
    --max-model-len 32768 \
    --gpu-memory-utilization 0.90 \
    --gdn-prefill-backend triton \
    --enforce-eager

