#!/bin/bash

# cleanup simplace runs for a user

USER=$1
RUN_ID=$2
ALL=$3 # default is false, if true, all runs for the user will be deleted

# check if run id is alphanumeric and contains only letters, numbers, lines and underscores
if [[ ! "$RUN_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Run ID $RUN_ID is not valid. It should only contain letters, numbers, lines and underscores."
    exit 1
fi


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
    if [ "$ALL" == "true" ] || [ "$run_id" == "$RUN_ID" ]; then
        echo "Cleaning up run $run_id for user $USER"
        rm -rf "${SIMPLACE_RUNS}/${run_id}"
        echo "Run $run_id cleaned up"
        if [ "$ALL" != "true" ]; then
            exit 0
        fi
    fi
done

if [ "$ALL" != "true" ]; then
echo "Run $RUN_ID not found for user $USER"
exit 1
fi