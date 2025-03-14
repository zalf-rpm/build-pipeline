# HPC first setup

Copy the scripts from /beegfs/common/singularity/vnc/scripts  
**mkdir -p ~/scripts**  
**cp -r /beegfs/common/singularity/vnc/scripts ~/scripts**  
**cd ~/scripts**

Check if a gpu node is available  

**sinfo**

```go
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
compute*     up   infinite     31    mix node[001-005,025-044,050,054,056,089-090,092]  
compute*     up   infinite      6  alloc node[052,093,096,098-100]  
compute*     up   infinite     62   idle node[006-024,045-049,051,053,055,057-069,071-088,091,094-095,097]  
compute*     up   infinite      1   down node070  
highmem      up   infinite     25   idle node[101-125]  
gpu          up   infinite      5   idle gpu[001-005]  
fat          up   infinite      2   idle fat[001-002]  

```
gpu needs to be in idle, to be used.


## start
**sbatch sbatch_vnc.sh**  

If no gpu node is available, you can start it on a compute node, just for installation.
Rootpainter will not work without a gpu.

**sbatch --partition=compute --time=01:00:00 sbatch_vnc.sh**

If you have trouble with a gpu node, gpu005 is sometimes not working with older python versions,  
you can exclude it with the -x option.  

**sbatch --partition=gpu -x gpu005 sbatch_vnc.sh**

### check which node you got
squeue
```go
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
            132663   compute  vnc-web   myUser  R       0:39      1 node052
          132652_1   compute  cz_hist  xxxxxxx  R    2:08:35      1 node054
          132652_2   compute  cz_hist  xxxxxxx  R    2:08:35      1 node056
          132652_3   compute  cz_hist  xxxxxxx  R    2:08:35      1 node089
          132652_4   compute  cz_hist  xxxxxxx  R    2:08:35      1 node090
          132652_5   compute  cz_hist  xxxxxxx  R    2:08:35      1 node092
            132662   compute sdba_jup  xxxxxxx  R      33:34      1 node050
            132591   compute mpi-migr  xxxxxxx  R 2-21:25:17      2 node[098-099]
            132588   compute mpi-migr  xxxxxxx  R 2-21:27:17      2 node[093,096]
            126652   compute no-shell  xxxxxxx  R 177-18:07:53      1 node100`
```

Last column is you node name  
First column is your job id  

## connect to your node

Open a new powershell on your windows and create a tunnel:

**ssh -N -L 6901:mynode:6901 myloginid@login02.cluster.zalf.de**

Replace mynode with your node name and myloginId with your Zalf loginId.

Open a new tab in your browser and enter
http://localhost:6901/

VNC will request a password.  
You will find a password file in your ~/scripts/vnc_password.txt.   
With every start a new random password will be generated.  

## stop

To stop your instance, use  
**scancel jobId**

## initial setup
Disable the screensaver and lock screen 

Application > Setting > Screensaver > 
Tab Screensaver 
Tab Lockscreen

disable both, else you will be locked out and cannot login anymore

## install miniconda
Copy the roottrainer_install.sh to your vnc instance.  
Open a terminal in your vnc instance and run it.  

**bash roottrainer_install.sh**

## start rootpainter
Copy the start_rootpainter.sh to your vnc instance.   
Open a terminal in your vnc instance change directory to your folder and run it with:  
**bash start_rootpainter.sh**

At the first run it will ask you for your sync directory.  
It's recommended to use the beegfs filesystem, e.g. /beegfs/your_user/rootpainter_sync directory.  

## error handling
If you get an error that the path cannot be found, look for your **root_painter_settings.json* file.  
Check if it has multiple entries for the sync directory, or spaces in the path.

