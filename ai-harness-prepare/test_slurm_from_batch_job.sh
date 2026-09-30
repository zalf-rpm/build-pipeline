#!/bin/bash
#SBATCH --job-name=test_slurm_from_batch_job
#SBATCH --output=logs/output_file_name_%j.out
#SBATCH --partition=compute,highmem
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:15:00

mkdir -p logs

echo -e "Starting Slurm job tests\n"
echo -e "sinfo\n"
sinfo
echo -e "\nTesting squeue\n"
squeue -u $USER
echo -e "\nTesting sacct\n"
sacct -u $USER --format=User,Jobname,partition,state,elapsed,AllocCPUS,ReqMem,AllocTRES%50,tresusageinave%50

echo -e "\nTesting sbatch from inside the batch job\n"
# test sbatch from inside the batch job
sbatch --test-only ~/batch/test_hostname.sh 

echo -e "\nTesting sbatch from ssh to login node\n"
# test submit job using ssh to login node
ssh login01 "sbatch ~/batch/test_hostname.sh"

sleep 10
# job should either be in the queue or completed by now
echo -e "\nChecking squeue after submitting jobs\n"
squeue -u $USER
echo -e "\nChecking sacct after submitting jobs\n"
sacct -u $USER --format=User,Jobname,partition,state,elapsed,AllocCPUS,ReqMem,AllocTRES%50,tresusageinave%50