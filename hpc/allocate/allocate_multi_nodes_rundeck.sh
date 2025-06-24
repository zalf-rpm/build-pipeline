#!/bin/bash
#/ usage: start ?estimated_time? ?partition?
set -eu
[[ $# < 2 ]] && {
  grep '^#/ usage:' <"$0" | cut -c4- >&2 ; exit 2;
}
export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:~/.local/bin:~/bin

echo "allocate node"

echo available nodes:
sinfo

TIME=$1
COMPUTE=$2
HIGHMEM=$3
FAT=$4
GPU_NVIDIA_TENSOR_CORE_H100=$5
GPU_NVIDIA_TESLA_V100=$6

MAX_COMPUTE=50 # maximum number of compute nodes that can be allocated, with this job
MAX_HIGHMEM=20 # maximum number of highmem nodes that can be allocated, with this job
MAX_FAT=2 # maximum number of fat nodes that can be allocated, with this job
MAX_GPU_NVIDIA_TENSOR_CORE_H100=1 # maximum number of gpu H100 nodes... currently only 1 node available
MAX_GPU_NVIDIA_TESLA_V100=4 # maximum number of gpu V100 nodes that can be allocated, with this job

# check if at least one of the partition options has a value > 0
if [ -z "$COMPUTE" ] && [ -z "$HIGHMEM" ] && [ -z "$FAT" ] && [ -z "$GPU_NVIDIA_TENSOR_CORE_H100" ] && [ -z "$GPU_NVIDIA_TESLA_V100" ]; then
    echo "Error: You must specify at least one partition option with a value greater than 0." >&2
    exit 1
fi
# prepare resource request string

# compute request
REQUEST=""
# if compute is > 0 & <= 40, set the compute request
if [ -n "$COMPUTE" ] && [ "$COMPUTE" -gt 0 ] && [ "$COMPUTE" -le $MAX_COMPUTE ]; then
    REQUEST="-N $COMPUTE --exclusive --immediate=10 --partition=compute --time=$TIME "
fi 
# highmem request
# if highmem is > 0 & <= 25, set the highmem request
if [ -n "$HIGHMEM" ] && [ "$HIGHMEM" -gt 0 ] && [ "$HIGHMEM" -le $MAX_HIGHMEM ]; then

    if [ -z "$REQUEST" ]; then
        REQUEST="-N $HIGHMEM --exclusive --immediate=10 --partition=highmem --time=$TIME "
    else
        REQUEST="$REQUEST : -N $HIGHMEM --exclusive --immediate=10 --partition=highmem --time=$TIME "
    fi
fi
# fat request
# if fat is > 0 & <= 2, set the fat request
if [ -n "$FAT" ] && [ "$FAT" -gt 0 ] && [ "$FAT" -le $MAX_FAT ]; then
    if [ -z "$REQUEST" ]; then
        REQUEST="-N $FAT --exclusive --immediate=10 --partition=fat --time=$TIME "
    else
        REQUEST="$REQUEST : -N $FAT --exclusive --immediate=10 --partition=fat --time=$TIME "
    fi
fi
# gpu-Nvidia-Tensor-Core-H100 request
# if gpu-Nvidia-Tensor-Core-H100 is > 0 & <= 1, set the gpu-Nvidia-Tensor-Core-H100 request
if [ -n "$GPU_NVIDIA_TENSOR_CORE_H100" ] && [ "$GPU_NVIDIA_TENSOR_CORE_H100" -gt 0 ] && [ "$GPU_NVIDIA_TENSOR_CORE_H100" -le $MAX_GPU_NVIDIA_TENSOR_CORE_H100 ]; then
    if [ -z "$REQUEST" ]; then
        REQUEST="-N $GPU_NVIDIA_TENSOR_CORE_H100 --exclusive --immediate=10 --partition=gpu -x gpu001,gpu002,gpu003,gpu004 --time=$TIME "
    else
        REQUEST="$REQUEST : -N $GPU_NVIDIA_TENSOR_CORE_H100 --exclusive --immediate=10 --partition=gpu -x gpu001,gpu002,gpu003,gpu004 --time=$TIME "
    fi
fi
# gpu-Nvidia-Tesla-V100 request
# if gpu-Nvidia-Tesla-V100 is > 0 & <= 4, set the gpu-Nvidia-Tesla-V100 request
if [ -n "$GPU_NVIDIA_TESLA_V100" ] && [ "$GPU_NVIDIA_TESLA_V100" -gt 0 ] && [ "$GPU_NVIDIA_TESLA_V100" -le $MAX_GPU_NVIDIA_TESLA_V100 ]; then
    if [ -z "$REQUEST" ]; then
        REQUEST="-N $GPU_NVIDIA_TESLA_V100 --exclusive --immediate=10 --partition=gpu -x gpu005 --time=$TIME "
    else
        REQUEST="$REQUEST : -N $GPU_NVIDIA_TESLA_V100 --exclusive --immediate=10 --partition=gpu -x gpu005 --time=$TIME "
    fi
fi  

DATE=$(date +%Y-%m-%d-%H-%M-%S)
WORKDIR=/home/$USER/logs/allocate
mkdir -p -m 700 $WORKDIR
LOGFILE=$WORKDIR/$DATE-out.log

# Test example for multiple nodes allocation:
# salloc -N 3 --exclusive --immediate=10 --partition=compute --time=00:05:00 \
#  : -N 2 --exclusive --immediate=10 --partition=highmem --time=00:05:00 \
#  : -N 1 --exclusive --immediate=10 --partition=fat --time=00:05:00 \
#  : -N 1 --exclusive --immediate=10 --partition=gpu -x gpu005 --time=00:05:00 \
#  --no-shell > ~/logs/allocate/$(date +%Y-%m-%d-%H-%M-%S)-out.log 2>&1

salloc $REQUEST --no-shell > $LOGFILE 2>&1

# this version will allocate multiple nodes,
# so we give an example, the user has to chose which node is the head node for the job

# read the log file to get the node name
# Example log output:
#salloc: Pending job allocation 190426
#salloc: job 190426 queued and waiting for resources
#salloc: job 190426 has been allocated resources
#salloc: Granted job allocation 190426
#salloc: Nodes node[067-068,070] are ready for job
#salloc: Nodes node[101-102] are ready for job
#salloc: Nodes fat002 are ready for job
#salloc: Nodes gpu003 are ready for job

sleep 15 # give some time for the salloc command to finish and write to the log file

# print the log file to the console
cat $LOGFILE

# echo usage instructions:
cat 1>&2 <<END
"
Choose a head node (my_head_node) from the list of allocated nodes. 

To connect to the node from a login node, use the following command:

ssh $USER@my_head_node

To connect to the node from your local machine with vscode to your head node:
- You need to have the Dev Container extension installed in vscode.
- You need to have an SSH key pair in your home directorys:
    The public key should be in /home/$USER/.ssh/authorized_keys on the cluster
    The private key should be in C:/Users/$USER/.ssh/id_rsa_openssh (it is recommended to use this name, makes copying easier, see below)
    You can use Puttygen to generate the key pair on Windows. 
- you need to prepare the config file for the SSH connection:
    (if you have connected with vscode to your head before you can skip this step)

    Create a C:/Users/$USER/.ssh/config file, if it does not exist.
    Add the following content, if you have never connected to your choosen head node:

    Host my_head_node
      HostName my_head_node.service
      User $USER
      IdentityFile C:/Users/$USER/.ssh/id_rsa_openssh
      ProxyJump $USER@login02.cluster.zalf.de:22

- Select Remote Explorer in the left menu, you can now choose the node in the list of SSH Targets.
- Select the node and enter your passphrase for the SSH key, if you have set one. It will ask twice.
- Once you are connected, select the "Open Folder" option
- Select the folder you want to work in. It will ask again for your passphrase for the SSH key, twice.
- 

 If you have problems with setting up the connection. Please contact your MAS admin.
 Please send us a note if you think we can improve this explanation. 

END