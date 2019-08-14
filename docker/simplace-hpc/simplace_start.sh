#!/bin/bash
SOLUTION=$1
PROJECT=$2
DEBUG=true
LINE_START=$4
LINE_END=$5
TESTRUN=$6

SIMPLACE_WORKDIR=/simplace/SIMPLACE_WORK
OUTDIR=/output


LOGLEVEL=" -loglevel=ERROR"
if [ $DEBUG = "true" ]; then
  LOGLEVEL=""
  ls -al /simplace/SIMPLACE_WORK
  ls -al /data
  ls -al /projects
  ls -al /output
fi

echo "using mounted solution $SIMPLACE_WORKDIR/$SOLUTION"

if [ $TESTRUN = "true" ]; then
    echo "Simplace: testrun for soulution: $SIMPLACE_WORKDIR/$SOLUTION"
    /simplace/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -w=$SIMPLACE_WORKDIR -o=$OUTDIR
else 
    echo "Simplace - Solution: $SIMPLACE_WORKDIR/$SOLUTION"
    echo "Simplace - Project: $SIMPLACE_WORKDIR/$PROJECT"
    echo "Simplace - Lines: $LINE_START-$LINE_END"
    /simplace/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -p=$SIMPLACE_WORKDIR/$PROJECT -t=CLUSTER -l=$LINE_START-$LINE_END $LOGLEVEL
fi  