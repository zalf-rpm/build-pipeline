#!/bin/sh -x

mkdir -p $WORKDIR 
mkdir -p $OUTPUTDIR
mkdir -p $DATADIR
mkdir -p $PROJECTDIR

LOGLEVEL=" -loglevel=ERROR"
if [ $DEBUG = "true" ]; then
  env
  java -version
  echo "ALL dir"
  ls -al
  echo "work dir"
  ls -al $WORKDIR
  echo "exe dir"
  ls -al $EXECDIR
  echo "out dir"
  ls -al $OUTPUTDIR
  echo "data dir"
  ls -al $DATADIR
  LOGLEVEL=""
fi

if [ $TESTRUN = "true" ]; then
    echo "Simplace in Docker: this is a testrun for soulution: $WORKDIR/$SOLUTION"
    $EXECDIR/simplace run -s=$WORKDIR/$SOLUTION -w=$WORKDIR -o=$OUTPUTDIR
else 
    echo "Simplace in Docker - Solution: $WORKDIR/$SOLUTION"
    echo "Simplace in Docker - Project: $WORKDIR/$PROJECT"
    echo "Simplace in Docker - Lines: $LINE_START-$LINE_END"
    $EXECDIR/simplace run -s=$WORKDIR/$SOLUTION -p=$WORKDIR/$PROJECT -w=$WORKDIR -o=$OUTPUTDIR -fd=$DATADIR -fp=$PROJECTDIR -l=$LINE_START-$LINE_END $LOGLEVEL
fi  
echo "output dir"
ls -alR $OUTPUTDIR