#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --partition=compute

OUT_ZIP=$1
OUT_ZIP_FINAL=$2
SINGULARITY_IMAGE=$3

OUTDIR=/outputs
OUTDIR_FINAL=/final

echo "outputs dir: " $OUT_ZIP
echo "outputs final dir: " $OUT_ZIP_FINAL

srun singularity run -B \
$OUT_ZIP:$OUTDIR,\
$OUT_ZIP_FINAL:$OUTDIR_FINAL \
${SINGULARITY_IMAGE} /accumulate_output/accumulate_output -infolder /outputs -outfolder /final

