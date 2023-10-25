#!/bin/bash -x
#SBATCH --partition=compute
#SBATCH --job-name=cleanup
#SBATCH --output=delete_folders.out
#SBATCH --time=24:10:00

cd /beegfs/rpm/projects/simplace/out

# list folders older than 3 years
find . -maxdepth 1 -type d -mtime +1095 -ls

# delete folders older than 3 years
find . -maxdepth 1 -type d -mtime +1095 -exec rm -rf {} \;

