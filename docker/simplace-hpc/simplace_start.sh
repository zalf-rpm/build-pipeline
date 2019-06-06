#!/bin/bash


echo "using mounted solution $SIMPLACE_WORKDIR/$SOLUTION"

LOGLEVEL=" -loglevel=ERROR"
if [ $DEBUG = "true" ]; then
  env
  java -version
  echo "ALL dir"
  ls -al
  echo "work dir"
  ls -al $SIMPLACE_WORKDIR
  echo "exe dir"
  ls -al $EXECDIR
  echo "out dir"
  ls -al $OUTPUTDIR
  echo "data dir"
  ls -al $DATADIR
  LOGLEVEL=""
fi
DATE=`date +%Y-%d-%B_%H%M%S`
OUTDIR_RUN=$OUTPUTDIR/run_$DATE

if [ $TESTRUN = "true" ]; then
    OUTDIR_RUN=${OUTPUTDIR}/test_run_${DATE}
else 
    OUTDIR_RUN=${OUTPUTDIR}/${LINE_START}-${LINE_END}_run_${DATE}
fi 
mkdir $OUTDIR_RUN
echo "output dir: " $OUTDIR_RUN
if [ $TESTRUN = "true" ]; then
    echo "Simplace: testrun for soulution: $SIMPLACE_WORKDIR/$SOLUTION"
    $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -w=$SIMPLACE_WORKDIR -o=$OUTDIR_RUN
else 
    echo "Simplace - Solution: $SIMPLACE_WORKDIR/$SOLUTION"
    echo "Simplace - Project: $SIMPLACE_WORKDIR/$PROJECT"
    echo "Simplace - Lines: $LINE_START-$LINE_END"
    $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -p=$SIMPLACE_WORKDIR/$PROJECT -w=$SIMPLACE_WORKDIR -o=$OUTDIR_RUN -fd=$DATADIR -fp=$PROJECTDIR -l=$LINE_START-$LINE_END $LOGLEVEL
fi  
if [ $DO_ZIP == "true"]; then
    echo "Content output dir:"
    ls -alR $OUTDIR_RUN
    if [ "$FINAL_OUT_NAME" = "none" ]; then
        # create a unique name for the output tar.gz
        FINAL_OUT_NAME=$(cat /proc/sys/kernel/random/uuid)
        echo "FINAL_OUT_NAME: $FINAL_OUT_NAME"
    fi 

    cd $OUTDIR_RUN
    for dir in */
    do
    base=$(basename "$dir")
    DATE=`date +%Y-%m-%d`
    tar -czf "$ZIP_OUTPUTDIR/${FINAL_OUT_NAME}_${DATE}_${base}.tar.gz" "$dir"
    done
fi 