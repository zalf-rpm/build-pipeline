#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

MOUNT_DATA=$1
MOUNT_WORK=$2
MOUNT_OUT=$3
OUT_ZIP=$4
MOUNT_PROJECT=$5
MOUNT_EXE=~/simplace_exe/simplace_exe
SOLUTION=$6
PROJECT=$7
SINGULARITY_IMAGE=$8
DEBUG=$9
LINE_START=${10}
LINE_END=${11}
FINAL_OUT_NAME=${12}
TESTRUN=${13}

EXECDIR=/simplace_exe
IMAGE_MOUNT_FOLDER=/simplace
SIMPLACE_WORKDIR=$IMAGE_MOUNT_FOLDER/SIMPLACE_WORK
DATADIR=$IMAGE_MOUNT_FOLDER/data
OUTDIR=$IMAGE_MOUNT_FOLDER/output
PROJECTDIR=$IMAGE_MOUNT_FOLDER/projects

IMAGE_OUT_ZIP=$IMAGE_MOUNT_FOLDER/output_final

LOGLEVEL=" -loglevel=ERROR"
if [ $DEBUG = "true" ]; then
  LOGLEVEL=""
fi

DATE=`date +%Y-%d-%B_%H%M%S`
MOUNT_OUTDIR_RUN=$MOUNT_OUT/run_$DATE

if [ $TESTRUN = "true" ]; then
    MOUNT_OUTDIR_RUN=${MOUNT_OUT}/test_run_${DATE}
else 
    MOUNT_OUTDIR_RUN=${MOUNT_OUT}/${LINE_START}-${LINE_END}_run_${DATE}
fi 

mkdir $MOUNT_OUTDIR_RUN
echo "output dir: " $MOUNT_OUTDIR_RUN

echo "using mounted solution $SIMPLACE_WORKDIR/$SOLUTION"

CMD="srun singularity run -B \
$MOUNT_WORK:$SIMPLACE_WORKDIR,\
$MOUNT_OUTDIR_RUN:$OUTDIR,\
$MOUNT_DATA:$DATADIR,\
$MOUNT_PROJECT:$PROJECTDIR,\
$MOUNT_EXE:$EXECDIR \
${SINGULARITY_IMAGE} "


if [ $TESTRUN = "true" ]; then
    echo "Simplace: testrun for soulution: $SIMPLACE_WORKDIR/$SOLUTION"
    $CMD $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -w=$SIMPLACE_WORKDIR -o=$OUTDIR
else 
    echo "Simplace - Solution: $SIMPLACE_WORKDIR/$SOLUTION"
    echo "Simplace - Project: $SIMPLACE_WORKDIR/$PROJECT"
    echo "Simplace - Lines: $LINE_START-$LINE_END"
    $CMD $EXECDIR/simplace run -s=$SIMPLACE_WORKDIR/$SOLUTION -p=$SIMPLACE_WORKDIR/$PROJECT -w=$SIMPLACE_WORKDIR -o=$OUTDIR -fd=$DATADIR -fp=$PROJECTDIR -l=$LINE_START-$LINE_END $LOGLEVEL
fi  

echo "Content output dir:"
ls -alR $MOUNT_OUTDIR_RUN
if [ "$FINAL_OUT_NAME" = "none" ]; then
	# create a unique name for the output tar.gz
	FINAL_OUT_NAME=$(cat /proc/sys/kernel/random/uuid)
	echo "FINAL_OUT_NAME: $FINAL_OUT_NAME"
fi 

cd $MOUNT_OUTDIR_RUN
for dir in */
do
base=$(basename "$dir")
tar -czf "$OUT_ZIP/${FINAL_OUT_NAME}_${base}.tar.gz" "$dir"
done