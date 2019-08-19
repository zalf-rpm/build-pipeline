#!/bin/bash

# create a home dir for wine 
mkdir -p /home/generic
export "HOME=/home/generic"

cd ${HERMES_HOME}
if  [ "${DEBUG}" == "true" ]; then
ls -al
fi 
xvfb-run -a wine $@