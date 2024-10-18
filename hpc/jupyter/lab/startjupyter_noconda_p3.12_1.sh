#!/bin/bash -x


WORKDIR=$1

cd $WORKDIR

# make sure jupyter is in PATH
export PATH=$WORKDIR/.local/bin:$PATH

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port 8888 