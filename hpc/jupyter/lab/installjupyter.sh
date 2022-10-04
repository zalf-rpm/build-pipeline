#!/bin/bash -x

WORKDIR=$1

cd $WORKDIR

source /opt/conda/etc/profile.d/conda.sh

ENVPATH=$WORKDIR/.conda/envs/jupyterenv

if [ ! -e ${ENVPATH} ] ; then
conda create -y --name jupyterenv
conda activate jupyterenv
conda install -y -c conda-forge jupyterlab
fi

JUPYTER_PATH=$WORKDIR/.jupyter/jupyter_server_config.py
if [ ! -e ${JUPYTER_PATH} ] ; then
conda activate jupyterenv
jupyter server --generate-config
HASH=$(python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('zalfjupyterhpc','sha1'))\")") 
sed -i "s/# c.ServerApp.password = .*/c.ServerApp.password = u'$HASH'/g" $WORKDIR/.jupyter/jupyter_server_config.py 
fi