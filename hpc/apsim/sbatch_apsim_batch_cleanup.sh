#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

APSIM_TEMP=$1
APSIM_SIM_FOLDER=$2
APSIM_OUT_FOLDER=$3

echo "apsim temp dir: " $APSIM_TEMP
rm -rf $APSIM_TEMP

cd ${APSIM_SIM_FOLDER}
for f in *.out; do 
    mv "$f" ${APSIM_OUT_FOLDER}
done
for f in *.sum; do 
    mv "$f" ${APSIM_OUT_FOLDER}
done

ZIPNAME=`basename ${APSIM_OUT_FOLDER}`
cd ${APSIM_OUT_FOLDER}/..
tar -czf ${ZIPNAME}.tar.gz ${ZIPNAME}