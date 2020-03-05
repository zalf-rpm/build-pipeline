#!/bin/bash -x
#SBATCH --partition=compute
MODE=$1
MONICA_WORKDIR=$2
CONSUMER=$3
MONICA_OUT=$4

if [ $MODE == "git" ] ; then 
  PATH_TO_CONSUMER="${CONSUMER%/*}"
  cd ${MONICA_WORKDIR}/${PATH_TO_CONSUMER}/out

  for f in *.csv; do 
      mv "$f" ${MONICA_OUT}
  done

  # cleanup working dir
  rm -rf $MONICA_WORKDIR
fi