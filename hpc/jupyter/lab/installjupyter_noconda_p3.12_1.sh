#!/bin/bash -x

WORKDIR=$1
READ_HASH=$2
# setup python env for ai kernels, (optional, default is false)
SETUP_AI_ENV_1=${3:-false}

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
ENVPATH=$WORKDIR/.local/share/pipx/venvs/jupyter
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
    echo "Creating python3.7 kernel"

    python3.7 -m venv $WORKDIR/.envs/python3.7
    source $WORKDIR/.envs/python3.7/bin/activate
    pip install ipykernel ipyparallel
    python3.7 -m ipykernel install --user --name python3.7 --display-name "Python 3.7"
    deactivate
fi 

if [ ! -e $WORKDIR/.envs/python3.8 ] ; then
    echo "Creating python3.8 kernel"

    python3.8 -m venv $WORKDIR/.envs/python3.8
    source $WORKDIR/.envs/python3.8/bin/activate
    pip install ipykernel ipyparallel
    python3.8 -m ipykernel install --user --name python3.8 --display-name "Python 3.8"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.9 ] ; then
    echo "Creating python3.9 kernel"

    python3.9 -m venv $WORKDIR/.envs/python3.9
    source $WORKDIR/.envs/python3.9/bin/activate
    pip install ipykernel ipyparallel
    python3.9 -m ipykernel install --user --name python3.9 --display-name "Python 3.9"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.11 ] ; then
    echo "Creating python3.11 kernel"

    python3.11 -m venv $WORKDIR/.envs/python3.11
    source $WORKDIR/.envs/python3.11/bin/activate
    pip install ipykernel ipyparallel
    python3.11 -m ipykernel install --user --name python3.11 --display-name "Python 3.11"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.10 ] ; then
    echo "Creating python3.10 kernel"

    python3.10 -m venv $WORKDIR/.envs/python3.10
    source $WORKDIR/.envs/python3.10/bin/activate
    pip install ipykernel ipyparallel
    python3.10 -m ipykernel install --user --name python3.10 --display-name "Python 3.10"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.13 ] ; then
    echo "Creating python3.13 kernel"

    python3.13 -m venv $WORKDIR/.envs/python3.13
    source $WORKDIR/.envs/python3.13/bin/activate
    pip install ipykernel ipyparallel
    python3.13 -m ipykernel install --user --name python3.13 --display-name "Python 3.13"
    deactivate
fi

if [ ! -e $WORKDIR/.envs/python3.12_default ] ; then

    python3.12 -m venv $WORKDIR/.envs/python3.12_default 
    source $WORKDIR/.envs/python3.12_default/bin/activate
    pip install ipykernel matplotlib seaborn numpy pandas scipy ipyparallel
    python3.12 -m ipykernel install --user --name python3.12_default --display-name "Python 3.12 Default"
    deactivate

fi

# AI kernel
if [[ $SETUP_AI_ENV_1 == "true" && ! -e $WORKDIR/.envs/pytorchcu121 ]] ; then

    python3.12 -m venv $WORKDIR/.envs/pytorchcu121
    source $WORKDIR/.envs/pytorchcu121/bin/activate
    echo "Installing ipykernel"
    pip install ipykernel ipyparallel

    echo "Installing GDAL"
    pip install GDAL==`gdal-config --version`

    echo "Installing pytorch packages"
    pip install torch torchvision torchaudio torchmetrics

    echo "Installing other deep learning packages"
    pip install pillow lightly lightning captum albumentations 

    echo "Installing Hyperparameter optimization packages"
    pip install ray bayesian-optimization hpbandster

    echo "Installing other Geospatial packages"
    pip install geopandas geos geotiff shapely rasterio fiona cartopy

    echo "Installing other packages"
    pip install matplotlib seaborn numpy pandas scikit-image scikit-learn scipy memory-profiler pyzmq netcdf4 nco

    echo "adding kernel to jupyter"
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

# set default ipykernel from pyton3 to python3.12_default
# c.MultiKernelManager.default_kernel_name = 'python3'
# set AI kernel as default if SETUP_AI_ENV_1 is true
if [ $SETUP_AI_ENV_1 == "true" ] ; then
    sed -i "s/# c.MultiKernelManager.default_kernel_name = .*/c.MultiKernelManager.default_kernel_name = 'pytorchcu121'/g" $WORKDIR/.jupyter/jupyter_server_config.py
else
    sed -i "s/# c.MultiKernelManager.default_kernel_name = .*/c.MultiKernelManager.default_kernel_name = 'python3.12_default'/g" $WORKDIR/.jupyter/jupyter_server_config.py
fi

fi