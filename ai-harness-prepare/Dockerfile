FROM zalfrpm/python3.14:1
# base image, using Python 3.14 image for
# HPC jupyter lab server from zalfrpm repository
# see build-pipeline/docker/noconda/py3.14_ubuntu26.04/Dockerfile for reference

ARG GID=900
ARG UID=900

RUN groupadd -g $GID slurm && useradd -r -u $UID -g slurm -s /sbin/nologin slurm

