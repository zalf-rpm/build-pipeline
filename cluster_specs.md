Our HPC cluster is a computation resource designed to support a wide range of scientific and engineering workloads. Below are the specifications of the cluster, including details about the compute nodes, storage options, SLURM configuration, and recommended usage practices.
Please note that cluster storage does not make backups. Users are advised to maintain their own backups of important data in the regular IT infrastructure of the organization.

# HPC Support Contact
- MAS workgroup (see intranet for contact details)

## Login Nodes:
- Total Nodes: 2
- CPUs per node: 40
- vCPUs per node: 80
- Memory per node: 96 GB
- Scratch space per node: 160 GB
- Node names: login01 to login02
- Node Type: jump/entry nodes only, no compute jobs allowed

## Partitions:

compute
- TotalNodes: 100
- CPUs per node: 40
- Memory per node: 96 GB
- vCPUs per node: 80
- Scratch space per node: 160 GB
- Node names: node001 to node100

gpu
- Total Nodes: 5
    - old GPU nodes: 4
    - new GPU node: 1
- old GPU nodes:
  - Nodes: 4
  - CPUs per node: 24
  - Memory per node: 96 GB
  - vCPUs per node: 48
  - Scratch space per node: 160 GB
  - GPUs per node: 2 NVIDIA V100
  - Node names: gpu001 to gpu004
- new GPU node:
  - Nodes: 1
  - CPUs per node: 64
  - Memory per node: 768 GB
  - vCPUs per node: 128
  - Scratch space per node: 28 TB SSD
  - GPUs per node: 4 NVIDIA H100
  - Node name: gpu005

highmem
- Total Nodes: 25
- CPUs per node: 40
- Memory per node: 160 GB
- vCPUs per node: 80
- Scratch space per node: 160 GB
- Node names: node101 to node125

fat
- Total Nodes: 2
- CPUs per node: 80
- Memory per node: 1.5 TB
- vCPUs per node: 160
- Scratch space per node: 160 TB
- Node names: fat001 to fat002

## Storage

- Home Directory: 
    - Location: /home/user
    - Total Capacity: 20 TB
    - Capacity per User: "No hard quotas enforced; fair use policy applies."
    - Backup: No
    - Type: ZFS on HDD
    - Network drive: Yes
    - Network connection Speed: 1 Gbps
    - Network Type: Ethernet
- Scratch Directory:
    - Location: /scratch
    - Total Capacity: depends on partition
    - Type: Local SSD on each node
    - Note: /scratch == /tmp on all nodes except gpu-new (gpu005)
    - Note for User: Please clean up after job completion.
- Parallel File System:
    - Location: /beegfs/user
    - Total Capacity: 160 TB
    - Capacity per User: "No hard quotas enforced; fair use policy applies."
    - Backup: No
    - Type: BeeGFS
    - Network drive: Yes
    - Network connection Speed: 10 Gbps
    - Network Type: Omnipath HDR100
- Archival Storage:
    - Location: /data01/department/user
    - Total Capacity: 1 PB
    - Capacity per User: 25 TB (increase possible)
    - Type: ZFS on HDD
    - Network drive: Yes
    - Network connection Speed: 1 Gbps
    - Network Type: Ethernet
    - Note: archive storage is not given to all users at the beginning, it needs to be requested.

## SLURM
- Version: 24.11

defaults for sbatch/srun commands:
    - Partition: compute
    - Time limit: infinite
    - CPUs: 1 
    - Memory: full node
    - vCPUs: 2
    - Note: "Warning: If you do not specify --mem, you will be allocated all memory on the node, preventing other jobs from running there. Please always specify --mem."
    - use --partition option to select the desired partition(s), comma separated if multiple partitions are needed. 
    
## Modules
- Environment Modules system is used for managing software packages.
- not many pre-installed software exists on the cluster, users are encouraged to install their own software in their home directories or use containerization (Singularity/Apptainer).

## Containerization
- Singularity is available for containerized applications.
- Shared images are stored in /beegfs/common/singularity.
- Using sif files is recommended for better performance, because they bundle small files into a single file.

## Common data directory
- Location: /beegfs/common
- /beegfs/common/singularity: shared Singularity images
- /beegfs/common/data: shared datasets for all users
- /beegfs/common/data/climate: climate datasets
- /beegfs/common/data/MIC: MIC datasets
- Note: please look for meta data files to get more information about the datasets.

## Recommendations
- For CPU intensive jobs, use the compute partition.
- For GPU jobs, use the gpu partition.
- For memory intensive jobs, use the highmem or fat partitions.
- Store your data files in the parallel file system for better I/O performance.
- Use your home directory only for scripts, configuration files, programs and source code.
- please install python, R environments and packages in beeGFS. home uses NFS, which is slow when it comes to many small files.
- Use scratch space for temporary files during job execution.
- Move results, raw data, or data that is needed for later reprocessing to archival storage for long-term retention.
- Clean up and backup your data regularly.
- Clean up your scratch space after job completion to free up resources.
- check the /tmp folder, some applications write temporary files there, that are sometimes not deleted automatically.
- Prefer larger files over many small files for better performance on parallel file systems.
- Use job arrays for running multiple similar jobs.


## What to do on login nodes
- File management (copying, moving, deleting files)
- Job submission and monitoring
- Editing scripts and code (using editors like vim, nano etc.) Do not run heavy IDEs like VSCode on login nodes.
- Compiling code
- Loading modules
- Tools like SCREEN, TMUX for session management are allowed on login nodes, but keep in mind that they may be cleared during maintenance or restarts.


## Restrictions
- No root access on compute nodes.
- No installation of system-wide software packages.
- User home directories are not backed up.
- Job scheduling policies must be followed.
- Resource limits (CPU, memory, etc.) must be respected.
- Do not run interactive jobs on login nodes. Login nodes may be restarted without notice.
- Do not start compute-intensive processes on login nodes.
- Only login nodes are accessible from outside the cluster network. Compute nodes are not directly accessible from outside for security reasons.
- It is possible to ssh through login nodes to access compute nodes, if you have a job running on a compute node. This connection is temporary and only allowed during the job runtime. It will be closed automatically when the job ends.

## Security
- Access to the cluster is restricted to users with valid linux accounts. (uid, gid set in AD/LDAP by IT department)
- SSH keys are recommended for secure access.
- Your account must not be shared with others.
- You can use your institutional VPN to connect to the campus network in order to use the cluster.
- Regular audits and monitoring are conducted to ensure security compliance.
- Do not share your home directory or personal data with other users.
- Do not store sensitive data on the cluster without proper encryption and access controls.

## Sharing data (suggestions)
- Set permissions so other users can access for example:
 /beegfs/user/shared folder or /data01/department/user/shared folder.
- By default, other users do not have access to your home, scratch, beegfs or data01 directories.
- It is possible to create groups, to share data securely among group members. Please contact the HPC support team for assistance in setting up user groups.
- If you want to share data on the common data directory (/beegfs/common), please contact the HPC support team (MAS) for approval.
- If you want to publish datasets contact the FDM workgroup for assistance.


##Cluster Policies:
- There is no Accounting or billing system in place, but usage is tracked for monitoring purposes.
- Always set a time limit for your jobs to help the scheduler. The time limit can be extended by an admin if needed.
- Users are responsible for cleaning up their own data in scratch and home directories.
- An admin will check on proper usage of the cluster resources periodically (Please be nice to each other).
- Do not allocate resources you do not need.
- Kill jobs that are no longer needed.
- Report any issues or bugs to the HPC support team.
- Fairshare weighting policies - are in place but can be ignored for now, because there are not so many users.


## GPU Nodes (Partition: gpu)

**Note on GPU Allocation:**
Currently, the cluster is configured for **exclusive node access** in the GPU partition.
- You cannot request a specific number of GPUs (e.g., `--gres=gpu:1` is NOT currently active).
- When you submit a job to a GPU node, you receive access to **all GPUs** on that node.
- **Recommendation:** Please ensure your code can utilize multiple GPUs if you land on a multi-GPU node, or be aware that you are reserving the entire resource.

| Node Name | GPU Model | Count | VRAM | CPU | RAM | Local Scratch |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **gpu001** | NVIDIA Tesla V100 SXM2 | 2 | 16 GB | 2x Intel Xeon Silver 4116 (2x12 cores) | 96 GB | 160 GB SSD |
| **gpu002** | NVIDIA Tesla V100 SXM2 | 2 | 16 GB | 2x Intel Xeon Silver 4116 (2x12 cores) | 96 GB | 160 GB SSD |
| **gpu003** | NVIDIA Tesla V100 SXM2 | 2 | 16 GB | 2x Intel Xeon Silver 4116 (2x12 cores) | 96 GB | 160 GB SSD |
| **gpu004** | NVIDIA Tesla V100 SXM2 | 2 | 16 GB | 2x Intel Xeon Silver 4116 (2x12 cores) | 96 GB | 160 GB SSD |
| **gpu005** | NVIDIA H100 | 4 | 80 GB |2x AMD EPYC 9334 (2x32 cores) | 768 GB | 28 TB SSD |

**Targeting Specific Hardware:**
To request the H100 node specifically, use the node list constraint:
`#SBATCH --nodelist=gpu005`


# Example sbatch script

    #!/bin/bash
    #SBATCH --job-name=my_job_name
    #SBATCH --output=output_file_name_%j.out
    #SBATCH --error=error_file_name_%j.err
    #SBATCH --partition=compute
    #SBATCH --ntasks=1
    #SBATCH --cpus-per-task=4
    #SBATCH --mem=16G
    #SBATCH --time=02:00:00
    
    arg1="input_file_1"
    arg2="input_file_2"
    
    python my_program arg1 arg2


Examples:

Basic CPU job submission

# Array job submission
To run multiple similar jobs with different inputs, you can use SLURM array jobs.
For example, to run 4 jobs with different input files, you can either
use sbatch with --array=0-${ARRAYSIZE}
or in the sbatch script:

    #SBATCH --array=0-3

    ARGS=("input1" "input2" "input3" "input4")
    INDEX=$SLURM_ARRAY_TASK_ID
    my_program ${ARGS[$INDEX]}

SLURM_ARRAY_TASK_ID is the index of the current array job, provided by SLURM.


# Clean up scratch after job completion:
You can use this trap function to clean up temporary files or directories created during the job execution.

    TMPDIR=/scratch/${USER}_job_${SLURM_JOB_ID}
    mkdir -p ${TMPDIR}
    # clean up at end of script
    function clean_up {
        # remove temporary directory
        rm -rf "${TMPDIR:?}"
        exit
    }
    # Always call "clean_up" when script ends
    # This even executes on job failure/cancellation
    trap 'clean_up' EXIT



Versioning your output files:
When you have multiple runs of the same job, it is useful to version your output files to avoid overwriting previous results.
Also make sure you don't overwrite your output files when running multiple jobs simultaneously.

you can use the SLURM_JOB_ID variable to create unique output file names for each job.
Or use DATE command to append a timestamp to your output files.

    DATE=$(date +%Y%m%d_%H%M%S)
    OUTPUT_FILE="output_${DATE}_job_${SLURM_JOB_ID}.txt"

# Apply only for what you need:
Request only the resources you actually need for your job to optimize cluster usage and reduce wait times.
For example, if your job only needs 4 CPUs and 8GB of memory, do not request more than that.

    #SBATCH --cpus-per-task=4
    #SBATCH --mem=8G

# heterogeneous jobs:
You can request different resources for different parts of your job using the ":" syntax in sbatch.

    #!/bin/bash
    #SBATCH --cpus-per-task=4 --mem-per-cpu=16g --ntasks=1
    #SBATCH hetjob
    #SBATCH --cpus-per-task=2 --mem-per-cpu=1g  --ntasks=8
    srun --het-group=0 run.app1 &
    srun --het-group=1 run.app2 &
    wait

This can also be done directly on the command line:
    sbatch --cpus-per-task=4 --mem-per-cpu=16g --ntasks=1 : \
         --cpus-per-task=2 --mem-per-cpu=1g  --ntasks=8 my.bash


## Standard Job Template
When writing scripts for this cluster, please use this standard header:

#!/bin/bash
#SBATCH --job-name=JOB_NAME
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1## Standard Job Template