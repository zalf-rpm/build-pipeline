#!/bin/bash -x
#SBATCH --partition=compute
#SBATCH --job-name=scratch_trap
#SBATCH --output=scratch_trap_%j.out
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# this is an example script to demonstrate trapping scratch directory usage
# and cleaning up scratch space after job completion

# create a unique scratch directory for this job
SCRATCH_DIR="/scratch/${USER}_scratch_trap_$SLURM_JOB_ID"
mkdir -p $SCRATCH_DIR
echo "Created scratch directory: $SCRATCH_DIR"
# function to clean up scratch directory on exit
cleanup() {
    echo "Cleaning up scratch directory: $SCRATCH_DIR"
    rm -rf $SCRATCH_DIR
    echo "Scratch directory removed."
}   
# trap EXIT signal to ensure cleanup is called on job completion
trap cleanup EXIT

# simulate some work in the scratch directory
echo "Starting work in scratch directory..."
cd $SCRATCH_DIR
# simulate file creation
for i in {1..5}; do
    echo "This is file $i" > file_$i.txt
    sleep 1
done
echo "Work completed in scratch directory."     

# example usage:
# sbatch scratch_trap.sh