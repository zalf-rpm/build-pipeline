FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    bzip2 \
    ca-certificates \
    wget \
    git \
    nano-tiny \
    tzdata \
    unzip \
    vim-tiny \
    openssh-client \
    less \
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic \
    xclip \
    build-essential \
    cm-super \
    dvipng \
    ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install software-properties-common -y
RUN add-apt-repository ppa:ubuntugis/ppa && apt-get update
RUN apt-get install gdal-bin -y && apt-get install libgdal-dev -y
RUN export CPLUS_INCLUDE_PATH=/usr/include/gdal && export C_INCLUDE_PATH=/usr/include/gdal

# R pre-requisites
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc \
    apt-utils \
    lftp \
    unrar \
    libv8-dev \
    libjq-dev \
    libjpeg-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libudunits2-dev \
    libgeos++-dev \
    libgdal-dev \
    lbzip2 \
    libproj-dev \
    libnetcdf-dev \
    netcdf-bin \
    postgis \
    libhdf5-dev \
    libsqlite3-dev && \
    apt-get install gdal-bin -y && \
    apt-get install proj-bin -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


ENV CONDA_DIR="/opt/conda"
ENV PATH="$CONDA_DIR/bin:$PATH"
ENV SHELL=/bin/bash

ARG MINICONDA_VERSION=py310_23.3.1

# install miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-0-Linux-x86_64.sh -O ~/miniconda.sh 
RUN /bin/bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh 
RUN $CONDA_DIR/bin/conda clean -y --all && \
    ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

#RUN conda update -n base -c defaults conda
RUN $CONDA_DIR/bin/conda install -c conda-forge cartopy
RUN $CONDA_DIR/bin/conda install -c conda-forge netcdf4
RUN $CONDA_DIR/bin/conda install -c conda-forge pyzmq
RUN $CONDA_DIR/bin/conda install -c conda-forge nco
RUN $CONDA_DIR/bin/conda clean -y --all