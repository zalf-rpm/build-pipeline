#!/bin/bash
#SBATCH --job-name=download-qwen
#SBATCH --partition=compute
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x-%j.out

set -euo pipefail

MODEL_NAME=Qwen/Qwen3-Coder-Next

CACHE=/beegfs/$USER/hpc-vllm/.cache/huggingface
mkdir -p "$CACHE" logs

SINGULARITY_IMAGE=/beegfs/common/singularity/vllm/vllm-openai.v0.26.0-cu129-ubuntu2404.sif

set +x
HF_TOKEN=$(cat /home/$USER/huggingface_access/token.txt)
export SINGULARITYENV_HF_TOKEN=$HF_TOKEN
set -x

singularity exec --cleanenv \
    -B "$CACHE:/root/.cache/huggingface" \
    "$SINGULARITY_IMAGE" \
    hf download "$MODEL_NAME" \
        --cache-dir /root/.cache/huggingface