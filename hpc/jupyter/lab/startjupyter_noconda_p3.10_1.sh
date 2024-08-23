#!/bin/bash -x


WORKDIR=$1

cd $WORKDIR

source $WORKDIR/.venv/jupyterenv/bin/activate

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port 8888 