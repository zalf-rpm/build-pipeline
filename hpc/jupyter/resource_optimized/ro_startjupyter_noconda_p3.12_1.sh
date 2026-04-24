#!/bin/bash -x


WORKDIR=$1
PORT=$2

cd $WORKDIR

# make sure jupyter is in PATH
export PATH=$WORKDIR/.local/bin:$PATH

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port $PORT 