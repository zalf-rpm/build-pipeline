#!/bin/bash -x

DEVICE=${1:-0}
MODEL=${2:-"Qwen/Qwen3-Coder-Next"}
PORT=${3:-8000}

# read token from file without exposing it in xtrace output
{ HF_TOKEN=$(cat /huggingface_token/token.txt); } 2>/dev/null

CUDA_VISIBLE_DEVICES=$DEVICE VLLM_ENABLE_CUDA_COMPATIBILITY=1 HF_TOKEN=$HF_TOKEN vllm serve "$MODEL" --port $PORT

