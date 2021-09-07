#!/bin/bash -x

#SBATCH -J archive_files
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --partition=compute

ARCHIVE_PATH=$1 #path to archive
BACKUP_PATH=$2 #path to backup

cp -R $ARCHIVE_PATH $BACKUP_PATH

