#!/bin/sh
env
java -version
if [ $TESTRUN = "true" ]; then
  echo "Simplace in Docker: this is a testrun for soulution: $WORKDIR/$SOLUTION"
  $EXECDIR/simplace run -s=$WORKDIR/$SOLUTION -w=/simplace/SIMPLACE_WORK -o=/output
else 
  echo "Simplace in Docker - Solution: $WORKDIR/$SOLUTION"
  echo "Simplace in Docker - Project: $WORKDIR/$PROJECT"
  echo "Simplace in Docker - Lines: $LINE_START-$LINE_END"
  $EXECDIR/simplace run -t=CLUSTER -s=$WORKDIR/$SOLUTION -p=$WORKDIR/$PROJECT -l=$LINE_START-$LINE_END -loglevel=ERROR
fi
