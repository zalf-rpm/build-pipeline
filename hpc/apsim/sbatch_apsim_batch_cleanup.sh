#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

APSIM_TEMP=$1
APSIM_SIM_FOLDER=$2
APSIM_OUT_FOLDER=$3

echo "apsim temp dir: " $APSIM_TEMP
rm -rf $APSIM_TEMP
DATE=`date +%Y-%d-%B_%H%M%S`
echo $DATE

mkdir -p /scratch/rpm
ZIPNAME=`basename ${APSIM_OUT_FOLDER}`
cd ${APSIM_OUT_FOLDER}/..
tar -czf /scratch/rpm/${ZIPNAME}.tar.gz ${ZIPNAME}

cp /scratch/rpm/${ZIPNAME}.tar.gz ./${ZIPNAME}.tar.gz 
rm /scratch/rpm/${ZIPNAME}.tar.gz 

DATE=`date +%Y-%d-%B_%H%M%S`
echo $DATE