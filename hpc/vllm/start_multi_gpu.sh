#!/bin/bash -x

NUM_DEVICES=${1:-4} # available GPUs
START_PORT=${2:-8000} # start port for the server

SINGULARITY_IMAGE=${3:-/beegfs/common/singularity/vllm/vllm-openai_qwen38-cu129.sif}

for ((i=0; i<NUM_DEVICES; i++)); do
    DEVICE=$i
    PORT=$((START_PORT + i))

    sh vllm_test.sh $DEVICE $PORT $SINGULARITY_IMAGE 
    sleep 15
done

echo "✅ Alle Instanzen wurden im Hintergrund gestartet!"
echo "Nutze 'ps aux | grep vllm' oder 'nvidia-smi' zur Überprüfung."
echo "Logs findest du in vllm_gpu_0.log bis vllm_gpu_$((NUM_DEVICES-1)).log"
    
wait