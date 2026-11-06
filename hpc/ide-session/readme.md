Situation and Problems:

starting a IDE session on HPC currently requires a salloc with no-shell option. Vscode is attached to the allocated node and the user can start a session. 
This has some side effects. The /tmp directory is not cleaned up after the session ends, and the user may not have access to the allocated node after the session ends. Multiple plugins leave there files in /tmp. There is a race condition where processes are not attached to the allocated node and may be killed when the session ends.

Agents started in vscode have too much access to the allocated node and cluster directories. This can lead to security issues and unintended resource usage. 
May violate the principles of good scientific practice. Some users share data in their cluster directories, and the agent may use it for unintended purposes.

Intended Solution:
dedicated singularity containers for each user session. The container will be started via sbatch script and will have a clean /tmp directory, which will be cleaned up when the session ends with trap. 
The container will be destroyed when the session ends, ensuring that no processes are left behind. 
The container will also have limited access to the cluster resources, preventing security issues and unintended resource usage.

## Overview

```
Rundeck job
  -> rundeck_start_ide_container.sh   (runs as the user on a login node)
       validates parameters, submits the sbatch job, waits for the launch file, prints it
  -> sbatch_start_ide_container_ai-harness_<version>.sh   (runs as the user on the allocated node)
       prepares scratch workdir, ssh keys and sshd config, starts sshd inside the singularity container,
       writes the launch file once sshd accepts connections
  -> user connects with VS Code (Remote - SSH) over the login node to the sshd in the container
```

Files:

| File | Purpose |
|---|---|
| `rundeck_start_ide_container.sh` | Rundeck entry point, input check, resource mapping, `sbatch` |
| `sbatch_start_ide_container_ai-harness_0.5.sh` | job script, deployed to `/beegfs/common/batch/` |
| `/beegfs/common/singularity/ai-harness/ai-harness_<version>.sif` | image, built from `ai-harness-prepare/Dockerfile` (needs `openssh-server`) |

## 1. Rundeck job (rundeck_start_ide_container.sh)

Starts a sbatch job that starts a singularity container for the user. The script is executed as the user on a login node.

Input parameters:

- USER  - username of the user starting the session, e.g. jdoe
- JOB_EXEC_ID - from rundeck, for matching the job with the rundeck job execution (job name: `ide_<JOB_EXEC_ID>`)
- LOGIN_HOST - login host for the HPC cluster, used for the ssh `ProxyJump` in the launch instructions
- TIME - timelimit for the job, e.g. 2:00:00 for 2 hours
- RESOURCES - resources definition for the job, maps to partition, CPU, GPU, memory (e.g. `10vCPUs-10gb-RAM`, `gpu-Nvidia-H100`)
- VERSION - version of the base image to use, e.g. 0.5 for `ai-harness_0.5.sif`. The sbatch script `sbatch_start_ide_container_ai-harness_<VERSION>.sh` must exist in `/beegfs/common/batch/`
- PROJECT_DIR - project directory to mount in the container (read-write), e.g. /beegfs/$USER/my_project

Optional parameters (empty or `none` = not used):

- MOUNT_DATA_SOURCE1-3 - e.g. input data directories (read-only)
- MOUNT_DATA_OUT - output data directory (read-write). It is created if it does not exist.

Input check: all given directories are validated before anything is submitted. All problems are collected and printed with the parameter name,
then the script aborts (exit 1). A wrong or inaccessible path is never silently replaced by `none`.
(PROJECT_DIR and MOUNT_DATA_OUT must be writable, the data sources readable. For a missing MOUNT_DATA_OUT the closest existing parent must be writable.)

After `sbatch` the script waits (up to 5 minutes) for the launch file and prints it as the output of the rundeck job. 
If the job ends before the session is ready, or no slot becomes available in time, the job is cancelled and the script aborts.

## 2. sbatch script (sbatch_start_ide_container_ai-harness_<version>.sh)

Starts an `sshd` as the user inside the singularity container. VS Code connects to it via ssh.

- Container: `singularity exec --containall` - clean environment, own PID/IPC namespace (all processes of the session die with the container), 
  nothing is mounted automatically. `--nv` is added on the gpu partition.
- Mounts: PROJECT_DIR (rw), data sources (ro), output directory (rw), the container home, and the node-local scratch directories below.
- Container home: `/beegfs/$USER/ide` (same path inside and outside). Contains `.ssh/authorized_keys`, the sshd host key (`.sshd_hostkey/`, created once, 
  so the fingerprint stays the same), the vscode-server installation and the extensions. It is shared by all sessions of the user and persists.
- Temporary files: `/tmp`, `/var/tmp` and `/run` of the container are bound to `/scratch/${USER}_ide_${SLURM_JOB_ID}`.
  The directory is removed on exit by a trap. The container runs in the background and the script waits for it, so that the signal handler
  (scancel / time limit send SIGTERM) runs immediately: it stops the container and then cleans up.
- sshd: runs without root, config is generated per job (public key login only, `AllowUsers $USER`, tcp forwarding on for VS Code).
  The port is a free port on the node. The user's key must be in `/beegfs/$USER/ide/.ssh/authorized_keys`; if that file is empty,
  it is initialised from `/home/$USER/.ssh/authorized_keys`.
- Start directory: sshd passes `IDE_PROJECT_DIR`, `~/.bashrc` of the container home changes into it, so terminals start in the project directory.

Known, harmless log messages: `WARNING: 'UsePAM no' is not supported in this build` (sshd of the AlmaLinux image, we run without root and PAM).

Not covered: if the job is killed with SIGKILL (or the node crashes) the trap cannot run and the scratch directory stays.
This needs an epilog or a cron job on the cluster that removes `/scratch/*_ide_*` of finished jobs.

## 3. Instructions for the user (launch file)

The sbatch script writes `/beegfs/$USER/ide/.launch_instructions/<jobid>.rundeck` as soon as sshd accepts connections
(written to a temporary file and moved, so rundeck never reads a partial file). The file is removed when the session ends.
It contains:

- what the container can see
- prerequisites: VS Code with the extension "Remote - SSH", ssh key pair
- the ssh config blocks for the login host and for `hpc-ide` (node, port and `ProxyJump` over the login host). For every session only `HostName` and `Port` change.
- how to connect: `code --remote ssh-remote+hpc-ide <PROJECT_DIR>`, or "Connect to Host" in VS Code, or `ssh hpc-ide`
- how to end the session: `scancel <jobid>` on the login node, otherwise it ends at the time limit

## Open points

- Which directories are mounted read-write (currently PROJECT_DIR, MOUNT_DATA_OUT and the container home) - check with users.
- If PROJECT_DIR is a parent of `/beegfs/$USER/ide` or of other shared data, the agent in the session can see all of it.
- Cleanup of left over `/scratch/*_ide_*` directories after SIGKILL / node crashes (cluster admin task).
