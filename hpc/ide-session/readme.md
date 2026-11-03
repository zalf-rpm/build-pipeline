Situation and Problems:

starting a IDE session on HPC currently requires a salloc with no-shell option. Vscode is attached to the allocated node and the user can start a session. 
This has some side effects. The /tmp directory is not cleaned up after the session ends, and the user may not have access to the allocated node after the session ends. Multiple plugins leave there files in /tmp. There is a race condition where processes are not attached to the allocated node and may be killed when the session ends.

Agents started in vscode have too much access to the allocated node and cluster directories. This can lead to security issues and unintended resource usage. 
May violate the priciples of good scientific practice. Some users share data in their cluster directories, and the agent may use it for unintended purposes.

Intended Solution:
dedicated singularity containers for each user session. The container will be started via sbatch script and will have a clean /tmp directory, which will be cleaned up when the session ends with trap. 
The container will be destroyed when the session ends, ensuring that no processes are left behind. 
The container will also have limited access to the cluster resources, preventing security issues and unintended resource usage.

1. Create a Rundeck job, using the rundeck_start_ide_container.sh script, which will start a sbatch job to start a singularity container for the user. The container will be started with the following parameters:

Input parameters:
USER  - username of the user starting the session, e.g. jdoe
JOB_EXEC_ID - from rundeck, for matching the job with the rundeck job execution
LOGIN_HOST - login host for the HPC cluster, e.g. to print the login command for the user to connect to the HPC cluster
TIME - timelimit for the job, e.g. 2:00:00 for 2 hours
RESOURCES - resources definition for the job, maps to CPU, GPU, memory 
VERSION - version of the base image to use, e.g. 0.4 for ai-harness_0.4.sif
PROJECT_DIR - project directory to mount in the container, e.g. /beegfs/$USER/my_project

OPTIONAL PARAMETERS:
MOUNT_DATA_SOURCE1-3 - e.g. input data directories (optional, can be none, read-only)
MOUNT_DATA_OUT - e.g. output data directory (optional, can be none, read-write)

2. the sbatch script to start the IDE container: sbatch_start_ide_container_<version>.sh (e.g., sbatch_start_ide_container_ai-harness_0.4.sh)
the singularity container will allow the user to connect to the container via ssh. Vscode will be configured to connect to the container via ssh. The container will have a clean /tmp directory, which will be cleaned up when the session ends with trap. The container will also have limited access to the cluster resources, preventing security issues and unintended resource usage.

3. there will be an instruction file generated for the user, that explains how to connect to the container via ssh and start the IDE session. The instruction file will shown as output of the rundeck job. 