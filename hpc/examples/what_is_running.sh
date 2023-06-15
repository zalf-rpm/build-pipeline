#!/bin/bash +x
# this is a template script for running a development environment on the HPC
# it is called by rundeck and should not be called manually
# this snippet is used to check if the job is already running


export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

SBATCH_JOB_NAME="jupyter_rdk"

#parse output of squeue for job name
BATCHID=$(squeue --noheader -o "%i" -n $SBATCH_JOB_NAME -u $(whoami))

# check if job is running
if [ -z "$BATCHID" ]
then
      echo "No job running"

      #do something to start the job
else
      echo "Job is already running"
      NODE=$(squeue --noheader -o "%R" -n $SBATCH_JOB_NAME -u $(whoami) )
      TIME=$(squeue --noheader -o "%.10M" -n $SBATCH_JOB_NAME -u $(whoami) )
      TIMESPAN=$(squeue --noheader -o "%.9l" -n $SBATCH_JOB_NAME -u $(whoami) )

      echo "Job ID: $BATCHID"
      echo "Node: $NODE"
      echo "Running since: $TIME"
      echo "Total time span: $TIMESPAN"
fi


