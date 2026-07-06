#!/bin/bash

# list all simplace run IDs for a user

USER=$1

USER_FOLDER=/beegfs/rpm/projects/simplace_user/${USER}

# check if user folder exists
if [ ! -d "$USER_FOLDER" ]; then
    echo "no jobs found for user $USER"
    exit 1
fi

# list all run IDs for the user
SIMPLACE_RUNS=${USER_FOLDER}/runs
# list all directories in the runs folder, which are the run IDs
if [ ! -d "$SIMPLACE_RUNS" ]; then
    echo "no jobs found for user $USER"
    exit 1
fi

for run_id in $(ls -d $SIMPLACE_RUNS/*/ | xargs -n 1 basename); do
    echo $run_id
done