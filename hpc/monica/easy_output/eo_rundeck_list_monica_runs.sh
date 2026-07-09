#!/bin/bash

# list all monica run IDs for a user

USER=$1

USER_FOLDER=/beegfs/rpm/projects/monica_user/${USER}

# check if user folder exists
if [ ! -d "$USER_FOLDER" ]; then
    echo "no jobs found for user $USER"
    exit 1
fi

# list all directories in the user folder, which are the run IDs
for run_id in $(ls -d $USER_FOLDER/*/ | xargs -n 1 basename); do
    echo $run_id
done