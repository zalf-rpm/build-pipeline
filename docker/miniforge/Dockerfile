FROM ubuntu:24.04
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


ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=${CONDA_DIR}/bin:${PATH}

ENV SHELL=/bin/bash

ARG MINIFORGE_NAME=Miniforge3
ARG MINIFORGE_VERSION=24.3.0-0

RUN wget --no-hsts --quiet https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/${MINIFORGE_NAME}-${MINIFORGE_VERSION}-Linux-$(uname -m).sh -O /tmp/miniforge.sh && \
/bin/bash /tmp/miniforge.sh -b -p ${CONDA_DIR} && \
rm /tmp/miniforge.sh && \
conda clean --tarballs --index-cache --packages --yes && \
find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
conda clean --force-pkgs-dirs --all --yes  && \
echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc

RUN $CONDA_DIR/bin/conda install cartopy
RUN $CONDA_DIR/bin/conda install netcdf4
RUN $CONDA_DIR/bin/conda install pyzmq
RUN $CONDA_DIR/bin/conda install nco
RUN $CONDA_DIR/bin/conda install geopandas
RUN $CONDA_DIR/bin/conda install rasterio
RUN $CONDA_DIR/bin/conda clean -y --all
RUN python -V

COPY ./python_version.sh /start.sh

CMD ["./start.sh"]