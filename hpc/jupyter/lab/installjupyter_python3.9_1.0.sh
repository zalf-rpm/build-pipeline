#!/bin/bash 

WORKDIR=$1
PASSWORD=$2

cd $WORKDIR

source /opt/conda/etc/profile.d/conda.sh

ENVPATH=$WORKDIR/.conda/envs/jupyterenv

# create conda environment if not already existing
if [ ! -e ${ENVPATH} ] ; then
conda create -y --name jupyterenv
conda activate jupyterenv
# install jupyterlab
conda install -y -c conda-forge jupyterlab
conda clean -y --all
fi
# create jupyter config if not already existing
JUPYTER_PATH=$WORKDIR/.jupyter/jupyter_server_config.py
if [ ! -e ${JUPYTER_PATH} ] ; then
conda activate jupyterenv
jupyter server --generate-config
fi
# set(reset) password
if [ ! -z "$PASSWORD" ] ; then
HASH=$(python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('$PASSWORD','sha1'))\")")
sed -i "s/# c.ServerApp.password = .*/c.ServerApp.password = u'$HASH'/g" $WORKDIR/.jupyter/jupyter_server_config.py 
fi