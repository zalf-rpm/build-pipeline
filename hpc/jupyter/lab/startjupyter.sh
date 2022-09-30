#!/bin/sh -x


WORKDIR=$1

cd $WORKDIR

if [[! -f .bashrc ]]
    conda init
fi

source .bashrc

ENVPATH=$WORKDIR/.conda/envs/jupyterenv

if [ ! -e ${ENVPATH} ] ; then
conda create --name jupyterenv
conda activate jupyterenv
conda install -c conda-forge jupyterlab

fi

conda activate jupyterenv

JUPYTER_PATH=$WORKDIR/.jupyter/jupyter_server_config.py
if [ ! -e ${JUPYTER_PATH} ] ; then
jupyter server --generate-config
fi

JUPYTERLAB_WORKSPACES_DIR=$WORKDIR

jupyter lab --no-browser --ip "*" --port 8888 