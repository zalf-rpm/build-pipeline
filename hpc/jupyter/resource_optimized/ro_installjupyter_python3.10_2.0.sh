#!/bin/bash 

WORKDIR=$1
READ_HASH=$2
cd $WORKDIR

HASH=""
# check if READ_HASH is true
if [ $READ_HASH == "true" ] ; then
    # read hash from file
    TRANS=${WORKDIR}/.rundeck/jupyter_trans.yml
    # check if setup file exists
    if [ ! -f ${TRANS} ] ; then
        echo "setup file not found"
        exit 1
    fi
    HASH=$( cat $TRANS)

    # strip leading and trailing whitespaces
    HASH=$( echo $HASH | xargs )

    # remove setup file 
    rm -f $TRANS

    # fail if no HASH is given
    if [ -z "$HASH" ] ; then
        echo "No HASH given"
        exit 1
    fi
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

# initialize password hash
if [ -z "$HASH" ] ; then
 # fail if no hash is given
    echo "No hash given"
    exit 1
fi

sed -i "s/# c.ServerApp.password = .*/c.PasswordIdentityProvider.hashed_password = u'$HASH'/g" $WORKDIR/.jupyter/jupyter_server_config.py 
sed -i "s/# c.ServerApp.password_required = .*/c.PasswordIdentityProvider.password_required = True/g" $WORKDIR/.jupyter/jupyter_server_config.py 
fi