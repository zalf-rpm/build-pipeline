#!/bin/bash -x
#/ usage: start ?user? ?job_exec_id? ?model? ?folder? ?projectname? ?projectdata? ?withdate? ?time? ?mail? 
set -eu
[[ $# < 9 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_EXEC_ID=$2
MODEL=$3
FOLDER=$4
PROJECTNAME=$5
PROJECTDATA=$6
WITHDATE=$7
TIME=$8
MAILONFAIL=$9

ARCHIVE_PATH=/data01/FDS/rpm/archive/projects 
JOB_NAME="archive"

if [ -z "$PROJECTNAME" ]; then 
    echo "missing valid project name"
    exit 1
fi

MPATH="none"
if [ $MODEL == "monica" ] ; then
    MPATH=/beegfs/rpm/projects/monica/out
elif [ $MODEL == "simplace" ]; then 
    MPATH=/beegfs/rpm/projects/simplace/out_zip
elif [ $MODEL == "hermes" ]; then
    MPATH=/beegfs/rpm/projects/hermes2go/out
fi

if [ $MPATH == "none" ] ; then
    echo "invalid model selected"
    exit 1
fi

if [ $WITHDATE == "true" ] ; then
    DATE=`date +%d_%B_%Y`
    PROJECTNAME=${PROJECTNAME}_$DATE
fi

SBATCH_JOB_NAME="${USER}_${JOB_NAME}_${JOB_EXEC_ID}"
DATE=`date +%Y-%d-%B_%H%M%S`

MAIL=""
if [ $MAILONFAIL == "true" ] ; then
    MAIL="--mail-type=FAIL --mail-user=${USER}@zalf.de"
fi

pwd

SBATCH_COMMANDS="--job-name=${SBATCH_JOB_NAME} --time=${TIME} -o log/archive/%j_${DATE}.txt $MAIL"
INPUT="$MPATH $FOLDER $PROJECTDATA $PROJECTNAME $MODEL $ARCHIVE_PATH"
sbatch $SBATCH_COMMANDS batch/sbatch_archive_targz.sh $INPUT 