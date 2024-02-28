#!/bin/bash 

WORKDIR=$1
PASSWORD=$2

cd $WORKDIR

source /opt/conda/etc/profile.d/conda.sh

ENVPATH=$WORKDIR/.conda/envs/jupyterenv

# create conda environment if not already existing
if [ ! -e ${ENVPATH} ] ; then
conda create -y --name jupyterenv python=3.10
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
echo "set password hash"
HASH=$(python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('$PASSWORD','sha1'))\")")
sed -i "s/# c.ServerApp.password = .*/c.PasswordIdentityProvider.hashed_password = u'$HASH'/g" $WORKDIR/.jupyter/jupyter_server_config.py 
sed -i "s/# c.ServerApp.password_required = .*/c.PasswordIdentityProvider.password_required = True/g" $WORKDIR/.jupyter/jupyter_server_config.py 
else

# set(reset) password after installation
echo "update password hash"
conda activate jupyterenv
HASH=$(python -c "exec(\"from jupyter_server.auth import passwd\nprint(passwd('$PASSWORD','sha1'))\")")
sed -i "s/c.PasswordIdentityProvider.hashed_password = .*/c.PasswordIdentityProvider.hashed_password = u'$HASH'/g" $WORKDIR/.jupyter/jupyter_server_config.py 
fi