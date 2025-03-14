#!/bin/bash

#Install Miniforge
mkdir -p ~/miniforge3
wget https://github.com/conda-forge/miniforge/releases/download/24.3.0-0/Miniforge3-24.3.0-0-Linux-x86_64.sh -O ~/miniforge3/miniforge.sh
bash ~/miniforge3/miniforge.sh -b -u -p ~/miniforge3
rm -rf ~/miniforge3/miniforge.sh

#Activate Miniforge
source ~/miniforge3/etc/profile.d/conda.sh
conda create -n roottrainer python=3.10 -y
conda activate roottrainer
pip install root-painter-trainer==0.2.27.0
