#!/bin/bash -x

# copy folder from monica out to target folder
# this script operate on users own account

# sometimes MAS aids in generating the run, 
# but the user should be able to copy the results to their own folder
COPY_FROM_USER=$1 # could be someone else that the actual user
RUN_ID=$2
TARGET_FOLDER=$3

# check if run id is alphanumeric and contains only letters, numbers, lines and underscores
if [[ ! "$RUN_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Run ID $RUN_ID is not valid. It should only contain letters, numbers, hyphens and underscores."
    exit 1
fi

# check if target folder is alphanumeric and contains only letters, numbers, hyphens, underscores and slashes
if [[ ! "$TARGET_FOLDER" =~ ^[a-zA-Z0-9_\/-]+$ ]]; then
    echo "Target folder $TARGET_FOLDER is not valid. It should only contain letters, numbers, hyphens, underscores and slashes."
    exit 1
fi

# check if target folder exists
if [ ! -d "$TARGET_FOLDER" ]; then
    echo "Target folder $TARGET_FOLDER does not exist."
    exit 1
fi

USER_FOLDER=/beegfs/rpm/projects/monica_user/${COPY_FROM_USER}
# target folder for the run id
TARGET_RUN_FOLDER="$TARGET_FOLDER/$RUN_ID"
# check if target run folder already exists
if [ -d "$TARGET_RUN_FOLDER" ]; then
    echo "Error: Target run folder $TARGET_RUN_FOLDER already exists. "
    exit 1
fi

echo "Copying run $RUN_ID for user $COPY_FROM_USER to $TARGET_FOLDER"
# create target folder for the run id
mkdir -p "$TARGET_RUN_FOLDER"

cp -R "$USER_FOLDER/$RUN_ID/out/"* "$TARGET_RUN_FOLDER/"
# get error code of the last command
if [ $? -ne 0 ]; then
    echo "Error: Copying run $RUN_ID for user $COPY_FROM_USER to $TARGET_FOLDER failed."
    exit 1
fi
echo "Run $RUN_ID copied to $TARGET_RUN_FOLDER"
