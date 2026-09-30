#!/bin/bash
#SBATCH --job-name=test_hostname
#SBATCH --output=batch/logs/output_file_name_%j.out
#SBATCH --partition=compute,highmem
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:15:00

echo -e "Running hostname command\n"
hostname