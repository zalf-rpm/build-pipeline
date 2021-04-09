#!/bin/bash -x
#/ usage: start ?user? ?job_name? ?job_exec_id? ?version? ?estimated_time? ?input_dir? ?out_dir? ?forward? ?reverse?  ?samplename? ?presets?

set -eu
[[ $# < 10 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}

echo "Set env"

export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

USER=$1
JOB_NAME=$2
JOB_EXEC_ID=$3
VERSION=$4
TIME=$5

INPUT_DIR=$6
OUT_DIR=$7

FORWARD=$8
REVERSE=$9
SAMPLENAME=${10}

#check if the singularity image exists 
IMAGE_DIR=~/singularity/megahit
SINGULARITY_IMAGE=megahit_${VERSION}.sif
IMAGE_PATH=${IMAGE_DIR}/${SINGULARITY_IMAGE}
mkdir -p $IMAGE_DIR
if [ ! -e ${IMAGE_PATH} ] ; then
echo "File '${IMAGE_PATH}' not found"
cd $IMAGE_DIR
# vout/megahit:release-v1.2.9
singularity pull docker://vout/megahit:${VERSION}
cd ~
fi

CMD_PRESET=""
if [ -z "${RD_OPTION_PRESETS+x}" ]; then 
    CMD_PRESET=""
else
    CMD_PRESET=" --presets $RD_OPTION_PRESETS --memory 1"
fi

MOUNT_LOG=$OUT_DIR/log
mkdir -p $MOUNT_LOG

INPUT=/input
OUT=/out

DATE=`date +%Y-%d-%B_%H%M%S`
NEW_OUT_DIR=out_${DATE}

SLURM_CMD="srun --nodes=1 --ntasks=1 --partition=compute --cpus-per-task=80 --output=${MOUNT_LOG}/megahit_slurm_${DATE}_%j.log"
SINGULARTIY_CMD="singularity run -B $INPUT_DIR:$INPUT,$OUT_DIR:$OUT --pwd $INPUT ${IMAGE_PATH}"
MEGAHIT_CMD="megahit -1 $FORWARD -2 $REVERSE -o $OUT/$NEW_OUT_DIR ${CMD_PRESET} --num-cpu-threads 80 --out-prefix $SAMPLENAME --min-contig-len 200"
#srun --nodes=1 --ntasks=1 --partition=compute --cpus-per-task=80 --output=${MOUNT_LOG}/megahit_slurm_%j.log \
#singularity run -B \
#$INPUT_DIR:$INPUT,\
#$OUT_DIR:$OUT \
#--pwd $INPUT \
#${IMAGE_PATH} \
#megahit -1 $FORWARD -2 $REVERSE -o $OUT ${CMD_PRESET} --num-cpu-threads 80 --out-prefix $SAMPLENAME --min-contig-len 200

$SLURM_CMD $SINGULARTIY_CMD $MEGAHIT_CMD
