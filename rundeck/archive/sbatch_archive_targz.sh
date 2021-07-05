#!/bin/bash -x

#SBATCH -J archive_files
#SBATCH --time=10:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --partition=compute

MPATH=$1 #path
FOLDER=$2 #folder name
PROJECTDATA=$3 #folder name
PROJECTNAME=$4 # out folder
MODEL=$5 #model name

DATE=`date +%d_%B_%Y`
ARCHIVE_PATH=/beegfs/rpm/archive/projects # path to archive

PDATA=$MPATH/project/$PROJECTDATA
if [ $PROJECTDATA == "none" ] ; then 
    PDATA=" "  
fi
ARCHIVE_PATH_PROJECT=$ARCHIVE_PATH/${PROJECTNAME}_$DATE
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

echo "tar -czf $ARCHIVE_PATH_PROJECT/results/${MODEL}_${FOLDER}.tar.gz $MPATH/out/$FOLDER"
echo "tar -czf $ARCHIVE_PATH_PROJECT/setup/${MODEL}_${PDATA}.tar.gz $PDATA"



