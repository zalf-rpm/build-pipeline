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
    python3 \
    python3-dev \
    python3-pip \
    python3.10-venv \
    libsqlite3-dev && \
    apt-get install gdal-bin -y && \
    apt-get install proj-bin -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# tools
RUN apt-get update --yes && apt-get install --yes htop
RUN apt-get install --yes libarchive13
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# install other Python versions, to chose from
RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update -y
RUN apt-get install python3.7 -y
RUN apt-get install python3.8 -y
RUN apt-get install python3.9 -y
RUN apt-get install python3.11 -y
RUN apt-get install python3.12 -y

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV SHELL=/bin/bash

# ARG PYTHON_VERSION=3.12.5

# # download and unpack python

# RUN wget --no-hsts --quiet https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz -O /tmp/python_${PYTHON_VERSION}.tgz && \
#     mkdir -p ${PYTHON_DIR} && \
#     tar -xzf /tmp/python_${PYTHON_VERSION}.tgz -C ${PYTHON_DIR} --strip-components=1 && \
#     rm /tmp/python_${PYTHON_VERSION}.tgz

RUN pip install cartopy
RUN pip install netcdf4
RUN pip install pyzmq
RUN pip install nco
RUN pip install geopandas
RUN pip install rasterio


COPY ./python_version.sh /start.sh

CMD ["sh", "./start.sh"]