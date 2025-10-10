#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute
#SBATCH -J ollama-web
#SBATCH --time=00:15:00
#SBATCH --cpus-per-task=80

WORKDIR=$1
MOUNT_OLLAMA=$2
MOUNT_OPEN_WEB_UI=$3 
SINGULARITY_IMAGE=$4

cd $WORKDIR

# check if secret key file exists
if [ ! -f .webui_secret_key ]; then
    # gegenerate secret key for open-webui
    echo "Secret key file not found: $WORKDIR/.webui_secret_key"
    KEY=$(openssl rand -base64 32)
    echo $KEY > .webui_secret_key
fi
# read secret key from the file
KEY=$(cat $WORKDIR/.webui_secret_key)

echo key: $KEY
ENV_VARS=WEBUI_SECRET_KEY=$KEY

singularity exec --env ${ENV_VARS} --cleanenv --nv -H $WORKDIR -W $WORKDIR -B $WORKDIR:$WORKDIR,$MOUNT_OLLAMA:/root/.ollama,$MOUNT_OPEN_WEB_UI:/app/backend/data $SINGULARITY_IMAGE bash /app/backend/start.sh