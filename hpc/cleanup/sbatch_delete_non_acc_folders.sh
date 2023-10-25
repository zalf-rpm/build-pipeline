#!/bin/bash -x
#SBATCH --partition=compute
#SBATCH --job-name=cleanup_non_acc
#SBATCH --output=delete_folders_non_acc.out
#SBATCH --time=24:10:00

cd /beegfs/rpm/projects/simplace/out_zip

# list folders that do not end with _acc and are older than 10 days
find . -maxdepth 1 -type d -not -name '*_acc' -mtime +10 -ls

# delete folders that do not end with _acc and are older than 10 days
find . -maxdepth 1 -type d -not -name '*_acc' -mtime +10 -exec rm -rf {} \;