#!/bin/bash
#SBATCH -J HermesBatchRun
#SBATCH --time=0:05:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --partition=compute
#SBATCH -o hermes-%j 
#SBATCH --array=0-3
ARGS=(1-80 81-160 161-240 241-320)

MYUSER=$(whoami)
EXECUTABLE=hermestogo
PROJECTDATA=/beegfs/$MYUSER/hermes/BBB/BBG_all.bat
CMDLINE="-module batch -concurrent 40 -logoutput -batch $PROJECTDATA -lines"

cd /home/$MYUSER/go/src/gitlab.com/zalf-rpm/hermesforsimplace/hermestogo

srun ./$EXECUTABLE $CMDLINE ${ARGS[$SLURM_ARRAY_TASK_ID]}
