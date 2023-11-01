#!/bin/bash -x
#/ usage: start ?user? ?model? ?all_empty? ?older_than?
set -eu
[[ $# < 4 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
MODEL=$2
ALL_EMPTY=$3 # true or false
OLDER_THAN=$4 # in days ALL, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 

if [ -z "$USER" ] ; then 
    # fail if user is empty
    echo "user is empty"
    exit 1
fi
if [ -z "$MODEL" ] ; then 
    # fail if model is empty
    echo "model is empty"
    exit 1
fi
if [ -z "$ALL_EMPTY" ] ; then 
    # fail if all_empty is empty
    echo "all_empty is empty"
    exit 1
fi
if [ -z "$OLDER_THAN" ] ; then 
    # fail if older_than is empty
    echo "older_than is empty"
    exit 1
fi

# check if model is one of (MONCICA, SIMPLACE)

if [ $MODEL != "MONICA" ] && [ $MODEL != "SIMPLACE" ] ; then 
    # fail if model is not one of (MONCICA, SIMPLACE)
    echo "model is not one of (MONCICA, SIMPLACE)"
    exit 1
fi

EXECUTING_USER=$(whoami)

OUTFOLDER=/beegfs/${EXECUTING_USER}/projects/
LOGFOLDER=/beegfs/${EXECUTING_USER}/projects/
if [ $MODEL == "MONICA" ] ; then 
    OUTFOLDER=${OUTFOLDER}monica/out/
    LOGFOLDER=${LOGFOLDER}monica/log/
fi
if [ $MODEL == "SIMPLACE" ] ; then 
    OUTFOLDER=${OUTFOLDER}simplace/out_zip/
    LOGFOLDER=${LOGFOLDER}simplace/log/
fi

echo "OUTFOLDER: $OUTFOLDER"
echo "LOGFOLDER: $LOGFOLDER"

# check if outfolder exists
if [ ! -d "$OUTFOLDER" ] ; then 
    # fail if outfolder does not exist
    echo "outfolder does not exist"
    exit 1
fi
# check if logfolder exists
if [ ! -d "$LOGFOLDER" ] ; then 
    # fail if logfolder does not exist
    echo "logfolder does not exist"
    exit 1
fi

# if monica, list all folders in outfolder with prefix $USER_
# if simplace, list all folders in outfolder with prefix simpl_$USER_
if [ $MODEL == "MONICA" ] ; then 
    FOLDERS=$(find $OUTFOLDER -maxdepth 1 -type d -name "${USER}_*" -printf '%f\n')
fi
if [ $MODEL == "SIMPLACE" ] ; then 
    FOLDERS=$(find $OUTFOLDER -maxdepth 1 -type d -name "simpl_${USER}_*" -printf '%f\n')
fi

echo "FOLDERS: $FOLDERS"
# if all_empty is true, remove all folders from the list that are not empty
if [ $ALL_EMPTY == "true" ] ; then 
    for FOLDER in $FOLDERS
    do
        echo "FOLDER: $FOLDER"
        # check if folder is empty
        if [ ! "$(ls -A $OUTFOLDER$FOLDER)" ] ; then 
            # remove folder from list
            FOLDERS=${FOLDERS//$FOLDER/}
        fi
    done
fi

echo "FOLDERS: $FOLDERS"
# if older_than is not ALL, remove all folders from the list that are not older than $OLDER_THAN days
if [ $OLDER_THAN != "ALL" ] ; then 
    for FOLDER in $FOLDERS
    do
        echo "FOLDER: $FOLDER"
        # check if folder is older than $OLDER_THAN days, if not remove it from list
        if [ -z $(find $OUTFOLDER$FOLDER -maxdepth 0 -type d -mtime +$OLDER_THAN -print) ] ; then 
            # remove folder from list
            FOLDERS=${FOLDERS//$FOLDER/}
        fi

    done
fi

echo "FOLDERS: $FOLDERS"

# do the same for logfolder
if [ $MODEL == "MONICA" ] ; then 
    FOLDERS_LOG=$(find $LOGFOLDER -maxdepth 1 -type d -name "${USER}_*" -printf '%f\n')
fi
if [ $MODEL == "SIMPLACE" ] ; then 
    FOLDERS_LOG=$(find $LOGFOLDER -maxdepth 1 -type d -name "${USER}_*" -printf '%f\n')
fi

echo "FOLDERS_LOG: $FOLDERS_LOG"
# if all_empty is true, remove all folders from the list that are not empty
if [ $ALL_EMPTY == "true" ] ; then 
    for FOLDER_LOG in $FOLDERS_LOG
    do
        echo "FOLDER_LOG: $FOLDER_LOG"
        # check if folder is empty
        if [ ! "$(ls -A $LOGFOLDER$FOLDER_LOG)" ] ; then 
            # remove folder from list
            FOLDERS_LOG=${FOLDERS_LOG//$FOLDER_LOG/}
        fi
    done
fi
# if older_than is not ALL, remove all folders from the list that are not older than $OLDER_THAN days
if [ $OLDER_THAN != "ALL" ] ; then 
    for FOLDER_LOG in $FOLDERS_LOG
    do
        echo "FOLDER_LOG: $FOLDER_LOG"
        # check if folder is older than $OLDER_THAN days
        if [ -z $(find $LOGFOLDER$FOLDER_LOG -maxdepth 0 -type d -mtime +$OLDER_THAN -print) ] ; then 
            # remove folder from list
            FOLDERS_LOG=${FOLDERS_LOG//$FOLDER_LOG/}
        fi
    done
fi

echo "FOLDERS_LOG: $FOLDERS_LOG"

# remova all output folder on the list 
for FOLDER in $FOLDERS
do
    echo "FOLDER: $FOLDER"
    # remove folder
    #rm -rf $OUTFOLDER$FOLDER
    echo "rm -rf $OUTFOLDER$FOLDER"
done

# remova all log folder on the list
for FOLDER_LOG in $FOLDERS_LOG
do
    echo "FOLDER_LOG: $FOLDER_LOG"
    # remove folder
    #rm -rf $LOGFOLDER$FOLDER_LOG
    echo "rm -rf $LOGFOLDER$FOLDER_LOG"
done