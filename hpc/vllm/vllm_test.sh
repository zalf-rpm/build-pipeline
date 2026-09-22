#!/bin/bash -x

DEVICE=${1:-0}
PORT=${2:-8000}
#SINGULARITY_IMAGE=${3:-/beegfs/common/singularity/vllm/vllm-openai.v0.26.0-cu129-ubuntu2404.sif}
SINGULARITY_IMAGE=${3:-/beegfs/common/singularity/vllm/vllm-openai_qwen38-cu129.sif}

#HOMEDIR=/beegfs/$USER/hpc-vllm
USER_SCRATCH=/scratch/vllm
mkdir -p ${USER_SCRATCH}
# Use local scratch for home and work directories, instead of BeeGFS
# may give better performance/loading times than using BeeGFS
HOMEDIR=$USER_SCRATCH/hpc-vllm
WORKDIR=${HOMEDIR}/workdir

mkdir -p ${HOMEDIR}
mkdir -p ${WORKDIR}/run
mkdir -p ${WORKDIR}/tmp
mkdir -p ${HOMEDIR}/.cache/huggingface

# JIT/compile caches produce many small files; keep them on local scratch, not BeeGFS
LOCAL_CACHE=${USER_SCRATCH}/hpc-vllm-cache
mkdir -p ${LOCAL_CACHE}/vllm ${LOCAL_CACHE}/flashinfer ${LOCAL_CACHE}/torchinductor

# cleanup users scratch on exit
#trap "rm -rf ${USER_SCRATCH}" EXIT

set +x
HF_TOKEN=$(cat /home/$USER/huggingface_access/token.txt)

export SINGULARITY_HOME=${HOMEDIR}
export SINGULARITY_BINDPATH="${WORKDIR}/run:/run,${WORKDIR}/tmp:/tmp,${HOMEDIR}/.cache/huggingface:/root/.cache/huggingface,${LOCAL_CACHE}/vllm:/root/.cache/vllm,${LOCAL_CACHE}/flashinfer:/root/.cache/flashinfer,${LOCAL_CACHE}/torchinductor:/root/.cache/torchinductor"

export SINGULARITYENV_CUDA_VISIBLE_DEVICES=$DEVICE
export SINGULARITYENV_VLLM_ENABLE_CUDA_COMPATIBILITY=1
export SINGULARITYENV_HF_TOKEN=$HF_TOKEN
# export SINGULARITYENV_NCCL_NET=Socket
# export SINGULARITYENV_NCCL_IB_DISABLE=1
# export SINGULARITYENV_NCCL_NET_PLUGIN=none
export SINGULARITYENV_TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor
#export SINGULARITYENV_OMP_NUM_THREADS=16

set -x

cd ${HOMEDIR}
singularity exec --cleanenv --nv \
    -H ${HOMEDIR} \
    -W ${HOMEDIR} \
    $SINGULARITY_IMAGE \
    vllm serve Qwen/Qwen3.8-27B \
    --port $PORT \
    --tensor-parallel-size 1 \
    --quantization fp8 \
    --max-model-len 32768 \
    --max-num-seqs 64 \
    --gpu-memory-utilization 0.90 \
    --max-cudagraph-capture-size 32 \
    --default-chat-template-kwargs '{"enable_thinking": false}' \
    --gdn-prefill-backend triton \
    --mm-encoder-tp-mode data > "vllm_gpu_${DEVICE}.log" 2>&1 &


# works but may be unstable
# singularity exec --cleanenv --nv \
#     -H ${HOMEDIR} \
#     -W ${HOMEDIR} \
#     $SINGULARITY_IMAGE \
#     vllm serve Qwen/Qwen3.8-27B \
#     --port $PORT \
#     --tensor-parallel-size 1 \
#     --max-model-len 131072 \
#     --max-num-seqs 256 \
#     --gpu-memory-utilization 0.92 \
#     --enable-auto-tool-choice \
#     --tool-call-parser qwen3_xml \
#     --reasoning-parser qwen3 \
#     --gdn-prefill-backend triton \
#     --mm-encoder-tp-mode data

# singularity exec --cleanenv --nv \
#     -H ${HOMEDIR} \
#     -W ${HOMEDIR} \
#     $SINGULARITY_IMAGE \
#     vllm serve Qwen/Qwen3.8-27B \
#     --port $PORT \
#     --tensor-parallel-size 1 \
#     --quantization fp8 \
#     --max-model-len 32768 \
#     --max-num-seqs 64 \
#     --gpu-memory-utilization 0.90 \
#     --enable-auto-tool-choice \
#     --tool-call-parser qwen3_xml \
#     --reasoning-parser qwen3 \
#     --gdn-prefill-backend triton \
#     --mm-encoder-tp-mode data