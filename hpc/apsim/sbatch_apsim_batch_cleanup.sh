#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

APSIM_TEMP=$1

echo "apsim temp dir: " $APSIM_TEMP
rm -rf $APSIM_TEMP
