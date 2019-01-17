#!/bin/sh -x

if [ "$SVN_CHECKOUT_PATH" = "none" ]; then
    echo "using mounted solution $SIMPLACE_WORKDIR/$SOLUTION"
    if [ -d $SIMPLACE_WORKDIR ] && [ -d $SIMPLACE_SOURCEDIR ]; then
        echo "error SIMPLACE_SOURCEDIR and SIMPLACE_WORKDIR, should be either or none "
        exit 1
    fi
    if [ -d $SIMPLACE_SOURCEDIR ]; then 
        mkdir $SIMPLACE_WORKDIR
        cd $SIMPLACE_SOURCEDIR
        cp -r * $SIMPLACE_WORKDIR
        cd $SIMPLACE_WORKDIR
        ls -al
    fi 
else
    echo "SVN checkout from: $SVN_CHECKOUT_PATH"
    # check if a work dir was mounted
    if [ -d $SIMPLACE_WORKDIR ]; then
        ls -al
        echo "work dir"
        ls -al $SIMPLACE_WORKDIR
        echo "error cannot create a checkout, workdir already mounted"
        exit 1
    fi
    mkdir -p $SIMPLACE_WORKDIR 
    cd $SIMPLACE_WORKDIR 
        SVN_CMD="svn checkout $SVN_CHECKOUT_PATH"
        if [ "$SVN_USER" != "none" ] && [ "$SVN_PASSWORD" != "none" ]; then
            SVN_CMD="svn checkout $SVN_CHECKOUT_PATH --username $SVN_USER --password $SVN_PASSWORD"
        fi
        $SVN_CMD 
    cd ..
fi 

mkdir -p $SIMPLACE_WORKDIR 
mkdir -p $OUTPUTDIR
mkdir -p $DATADIR
mkdir -p $PROJECTDIR
mkdir -p $FINAL_OUTPUTDIR

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
if [ $SVN_CHECKOUT_PATH = "NONE" ]; then
    echo "using mounted solution $SIMPLACE_WORKDIR/$SOLUTION"
else
    echo "SVN checkout from: $SVN_CHECKOUT_PATH"
fi 
if [ $TESTRUN = "true" ]; then
    echo "Simplace in Docker: this is a testrun for soulution: $SIMPLACE_WORKDIR/$SOLUTION"
    $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -w=$SIMPLACE_WORKDIR -o=$OUTPUTDIR
else 
    echo "Simplace in Docker - Solution: $SIMPLACE_WORKDIR/$SOLUTION"
    echo "Simplace in Docker - Project: $SIMPLACE_WORKDIR/$PROJECT"
    echo "Simplace in Docker - Lines: $LINE_START-$LINE_END"
    $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -p=$SIMPLACE_WORKDIR/$PROJECT -w=$SIMPLACE_WORKDIR -o=$OUTPUTDIR -fd=$DATADIR -fp=$PROJECTDIR -l=$LINE_START-$LINE_END $LOGLEVEL
fi  
echo "output dir"
ls -alR $OUTPUTDIR
cd $OUTPUTDIR
for dir in */
do
  base=$(basename "$dir")
  tar -czf "$FINAL_OUTPUTDIR/${base}.tar.gz" "$dir"
done