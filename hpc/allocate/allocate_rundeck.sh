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
PARTITION=$2

HPC_PARTITION="--partition=compute"
if [ $PARTITION == "highmem" ] ; then 
    HPC_PARTITION="--partition=highmem"
elif [ $PARTITION == "gpu-Nvidia-Tesla-V100" ] ; then 
    HPC_PARTITION="--partition=gpu -x gpu005"
elif [ $PARTITION == "gpu-Nvidia-Tensor-Core-H100" ] ; then 
    HPC_PARTITION="--partition=gpu -x gpu001,gpu002,gpu003,gpu004"
elif [ $PARTITION == "fat" ] ; then 
    HPC_PARTITION="--partition=fat"
fi

DATE=$(date +%Y-%m-%d-%H-%M-%S)
WORKDIR=/home/$USER/logs/allocate
mkdir -p -m 700 $WORKDIR
LOGFILE=$WORKDIR/$DATE-out.log

# salloc -N 1 --exclusive --immediate=10 --partition=compute --time=00:05:00 --no-shell > /home/user/logs/allocate/$(date +%Y-%m-%d-%H-%M-%S)-out.log 2>&1 &
# allocate node and redirect standard output and error to log file 
salloc -N 1 --exclusive --immediate=10 $HPC_PARTITION --time=$TIME --no-shell > $LOGFILE 2>&1

# read the log file to get the node name
# Example log output:
# salloc: Granted job allocation 135688
# salloc: Nodes node053 are ready for job
while read line; do
    if [[ $line == *"salloc: Nodes"* ]]; then
        # salloc: Nodes node053 are ready for job
        # get node053 from the line
        NODE=$(echo $line | awk -F ' ' '{print $3}')
        
        echo "Allocated node: $NODE"
        break
    fi
done < $LOGFILE

if [ -z "$NODE" ]; then
    echo "Error: Could not allocate a node. Check the log file $LOGFILE for details." >&2
    exit 1
fi

# echo usage instructions:
cat 1>&2 <<END
"To connect to the node from a login node, use the following command:

ssh $USER@$NODE

To connect to the node from your local machine with vscode to the cluster node $NODE:
- You need to have the Dev Container extension installed in vscode.
- You need to have an SSH key pair in your home directorys:
    The public key should be in /home/$USER/.ssh/authorized_keys on the cluster
    The private key should be in C:/Users/$USER/.ssh/id_rsa_openssh (it is recommended to use this name, makes copying easier, see below)
    You can use Puttygen to generate the key pair on Windows. 
- you need to prepare the config file for the SSH connection:
    (if you have connected with vscode to $NODE before you can skip this step)

    Create a C:/Users/$USER/.ssh/config file, if it does not exist.
    Add the following content, if you have never connected to $NODE:
    
    Host login02.cluster.zalf.de
      HostName login02.cluster.zalf.de
      User $USER
      IdentityFile C:/Users/$USER/.ssh/id_rsa_openssh

    Host $NODE
      HostName $NODE.service
      User $USER
      IdentityFile C:/Users/$USER/.ssh/id_rsa_openssh
      ProxyJump $USER@login02.cluster.zalf.de:22

- Select Remote Explorer in the left menu, you can now choose $NODE in the list of SSH Targets.
- Select $NODE, enter your passphrase for the SSH key, if you have set one. It will ask twice.
- Once you are connected, select the "Open Folder" option
- Select the folder you want to work in. It will ask again for your passphrase for the SSH key, twice.
- 

 If you have problems with setting up the connection. Please contact your MAS admin.
 Please send us a note if you think we can improve this explanation. 

END