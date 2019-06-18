#!/bin/bash -x
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=0:05:00
#SBATCH --cpus-per-task=5
#SBATCH --partition=compute
#SBATCH -o monica-%j

NUM_WORKER=5
PROXY_SERVER=login01.cluster.zalf.de
MOUNT_STORAGE=/beegfs/common/data/climate
SINGULARITY_IMAGE=monica-cluster_2.2.1.168.sif
WORKDIR=/monica_data/climate-data
LOGOUT=/var/log
MOUNT_LOG=~/log

export monica_instances=$NUM_WORKER
export monica_intern_in_port=6677
export monica_intern_out_port=7788
export monica_autostart_proxies=false
export monica_autostart_worker=true
export monica_auto_restart_proxies=false
export monica_auto_restart_worker=true
export monica_proxy_in_host=$PROXY_SERVER
export monica_proxy_out_host=$PROXY_SERVER

srun singularity run -B \
$MOUNT_STORAGE:$WORKDIR,\
$MOUNT_LOG:$LOGOUT \
--pwd / \
${SINGULARITY_IMAGE} 
