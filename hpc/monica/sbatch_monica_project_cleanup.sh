#!/bin/bash -x
#SBATCH --partition=compute
MODE=$1
MONICA_WORKDIR=$2

if [ $MODE == "git" ] ; then 
  # cleanup working dir
  rm -rf $MONICA_WORKDIR
fi