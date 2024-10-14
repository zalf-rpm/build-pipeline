#!/bin/bash -x

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
# check if jupyter venv exists, if not install jupyter
ENVPATH=$WORKDIR/.local/pipx/venvs/jupyter
if [ ! -e ${ENVPATH} ] ; then
    pipx install jupyter --include-deps --python python3.12
    pipx inject jupyter jupyterlab-git jupyterlab-drawio matplotlib pandas ipykernel ipyparallel jupyterlab-nvdashboard
    pipx install poetry
    pipx ensurepath



fi
# make sure jupyter is in PATH
export PATH=$WORKDIR/.local/bin:$PATH

# install more kernels

# create env for each python version

if [ ! -e $WORKDIR/.envs/python3.7 ] ; then

    python3.7 -m venv $WORKDIR/.envs/python3.7
    source $WORKDIR/.envs/python3.7/bin/activate
    pip install ipykernel
    python3.7 -m ipykernel install --user --name python3.7 --display-name "Python 3.7"
    deactivate
fi 

if [ ! -e $WORKDIR/.envs/python3.8 ] ; then

    python3.8 -m venv $WORKDIR/.envs/python3.8
    source $WORKDIR/.envs/python3.8/bin/activate
    pip install ipykernel
    python3.8 -m ipykernel install --user --name python3.8 --display-name "Python 3.8"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.9 ] ; then

    python3.9 -m venv $WORKDIR/.envs/python3.9
    source $WORKDIR/.envs/python3.9/bin/activate
    pip install ipykernel
    python3.9 -m ipykernel install --user --name python3.9 --display-name "Python 3.9"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.10 ] ; then

    python3.10 -m venv $WORKDIR/.envs/python3.10
    source $WORKDIR/.envs/python3.10/bin/activate
    pip install ipykernel
    python3.10 -m ipykernel install --user --name python3.10 --display-name "Python 3.10"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.11 ] ; then

    python3.11 -m venv $WORKDIR/.envs/python3.11
    source $WORKDIR/.envs/python3.11/bin/activate
    pip install ipykernel
    python3.11 -m ipykernel install --user --name python3.11 --display-name "Python 3.11"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.12 ] ; then

    python3.12 -m venv $WORKDIR/.envs/python3.12
    source $WORKDIR/.envs/python3.12/bin/activate
    pip install ipykernel
    python3.12 -m ipykernel install --user --name python3.12 --display-name "Python 3.12"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.13 ] ; then

    python3.13 -m venv $WORKDIR/.envs/python3.13
    source $WORKDIR/.envs/python3.13/bin/activate
    pip install ipykernel
    python3.13 -m ipykernel install --user --name python3.13 --display-name "Python 3.13"
    deactivate
fi

# AI kernels

# pytorch 

if [ ! -e $WORKDIR/.envs/pytorch ] ; then

    python3.12 -m venv $WORKDIR/.envs/pytorchcu121
    source $WORKDIR/.envs/pytorch/bin/activate
    pip install ipykernel torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    python3.12 -m ipykernel install --user --name pytorchcu121 --display-name "PyTorch CUDA 12.1"
    deactivate
fi



# create jupyter config if not already existing
JUPYTER_PATH=$WORKDIR/.jupyter/jupyter_server_config.py
if [ ! -e ${JUPYTER_PATH} ] ; then
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