#!/bin/bash -x

WORKDIR=$1
cd $WORKDIR

# read password from file
TRANS=${WORKDIR}/.rundeck/jupyter_trans.yml
# check if setup file exists
if [ ! -f ${TRANS} ] ; then
    echo "setup file not found"
    exit 1
fi
# get the second argument from the setup file
PASSWORD=$( cat $TRANS | cut -d' ' -f2)

# strip leading and trailing whitespaces
PASSWORD=$( echo $PASSWORD | xargs )

# remove setup file 
rm -f $TRANS

# fail if no password is given
if [ -z "$PASSWORD" ] ; then
    echo "No password given"
    exit 1
fi

source /opt/conda/etc/profile.d/conda.sh

ENVPATH=$WORKDIR/.conda/envs/jupyterenv

# create conda environment if not already existing
if [ ! -e ${ENVPATH} ] ; then
conda create -y --name jupyterenv python=3.10
conda activate jupyterenv
# install jupyterlab and other packages
conda clean -y --index-cache
conda install -y -c conda-forge jupyterlab
conda clean -y --index-cache
conda install -y -c conda-forge ipywidgets
conda clean -y --index-cache
conda install -y -c conda-forge widgetsnbextension
conda clean -y --index-cache
conda install -y -c conda-forge matplotlib-base
conda clean -y --index-cache
conda install -y -c conda-forge pandas
conda clean -y --index-cache
conda install -y -c conda-forge scipy
conda clean -y --index-cache
conda install -y -c conda-forge seaborn
conda clean -y --index-cache
conda install -y -c conda-forge jupyterlab-git
conda clean -y --index-cache
conda install -y -c conda-forge jupyterlab-drawio

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