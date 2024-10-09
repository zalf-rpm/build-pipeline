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
if [ -d $WORKDIR/.local/pipx/venvs/jupyter ] ; then
    echo "Jupyter venv already exists"
else
    pipx install jupyter --include-deps --python python3.12
    pipx inject jupyter jupyterlab-git jupyterlab-drawio matplotlib pandas ipykernel
    pipx install poetry
    pipx ensurepath
fi
# make sure jupyter is in PATH
export PATH=$WORKDIR/.local/bin:$PATH

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