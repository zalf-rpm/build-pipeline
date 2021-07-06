#!/bin/bash -x

#SBATCH -J archive_files
#SBATCH --time=10:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --partition=compute

MPATH=$1 #path
FOLDER=$2 #folder name
PROJECTDATA=$3 #folder path
PROJECTNAME=$4 # out folder
MODEL=$5 #model name
ARCHIVE_PATH=$6 #path to archive

ARCHIVE_PATH_PROJECT=$ARCHIVE_PATH/${PROJECTNAME}
METAFILE=$ARCHIVE_PATH_PROJECT/proj.meta

mkdir -p $ARCHIVE_PATH_PROJECT/setup
mkdir -p $ARCHIVE_PATH_PROJECT/results

if [ -f "$METAFILE" ] ; then
ARCIVE_DATE=`date '+%d.%B.%Y %H:%M:%S'`
echo -e "  - $ARCIVE_DATE" >> $ARCHIVE_PATH_PROJECT/proj.meta
else
ARCIVE_DATE=`date +%d.%B.%Y`
touch $ARCHIVE_PATH_PROJECT/proj.meta
echo -e "project: $PROJECTNAME\ndate: $ARCIVE_DATE\nsetup: ./setup\nresults: ./results\nnote: none \nupdates: \n" >> $ARCHIVE_PATH_PROJECT/proj.meta
fi

if [ $MPATH != "none" ] ; then 
    cd $MPATH
    tar -czf $ARCHIVE_PATH_PROJECT/results/${MODEL}_${FOLDER}.tar.gz $FOLDER
fi 

if [ $PROJECTDATA != "none" ] ; then 
    
    if [ -d "$PROJECTDATA" ]; then
        echo "$PROJECTDATA is a directory"
        cd $PROJECTDATA/..
    elif [ -f "$PROJECTDATA" ]; then
        echo "$PROJECTDATA is a file"
        cd ${PROJECTDATA%/*}
    else
        echo "$PROJECTDATA is not valid"
        exit 1
    fi
    PTARGET=`basename $PROJECTDATA`
    ZIP_FILE=$ARCHIVE_PATH_PROJECT/setup/${MODEL}_${PTARGET}.tar.gz

    if [ -e "$ZIP_FILE" ]; then 
        echo "$ZIP_FILE already exists"
    else 
        tar -czf $ZIP_FILE $PTARGET
    fi
fi




