# VNC on HPC

This folder contains the scripts for running a browser-based VNC session on the cluster.

## Files

- `ubuntu-26-xfce-vnc-gpu.def`
	- Singularity definition based on Ubuntu 26.04 LTS.
	- Installs required packages directly in `%post`.
- `sbatch_vnc.sh`
	- SLURM batch runtime script.
	- Creates and cleans `/scratch/$USER/vnc-temp` via `trap EXIT`.
	- Writes session password to `vnc_password.txt` in the submit directory.
- `start_vnc_rundeck.sh`
	- Rundeck-style wrapper to submit and describe the job.
- `start_vnc_test.sh`
	- Lightweight launcher for manual testing without Rundeck.

## Required mounts used by `sbatch_vnc.sh`

- Home inside container: `/home/$USER/hpc-vnc`
- `/home/$USER` -> `/myhome`
- `/beegfs/$USER` -> `/beegfs/$USER`
- `/beegfs/common` -> `/beegfs/common`
- `/scratch/$USER/vnc-temp` -> `/tmp`
- Optional: `/data01/PB/$USER` -> `/data01/PB/$USER` (if directory exists)

## Typical flow

1. Build image from `ubuntu-26-xfce-vnc-gpu.def`.
2. Place resulting image, for example, at:
	 - `/beegfs/common/singularity/vnc/ubuntu-26-xfce-vnc-gpu.sif`
3. Submit via Rundeck wrapper or test wrapper.
4. Create SSH tunnel to node port 6901.
5. Open `http://localhost:6901`.

## Notes

- Scripts are created from repo patterns but cannot be validated on this PC.
- If your site uses `apptainer` instead of `singularity`, replace command names accordingly.


