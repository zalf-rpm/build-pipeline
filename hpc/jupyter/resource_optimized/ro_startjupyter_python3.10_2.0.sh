#!/bin/bash -x


WORKDIR=$1
PORT=$2

cd $WORKDIR

source /opt/conda/etc/profile.d/conda.sh
conda activate jupyterenv

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port $PORT