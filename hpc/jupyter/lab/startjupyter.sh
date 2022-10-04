#!/bin/bash -x


WORKDIR=$1

cd $WORKDIR

source /opt/conda/etc/profile.d/conda.sh
conda activate jupyterenv

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port 8888 