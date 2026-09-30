FROM almalinux:9

# enable EPEL, CRB (for -devel packages) and RPM Fusion (ffmpeg, unrar)
RUN dnf update -y && \
    dnf install -y epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled crb && \
    dnf install -y \
      https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm \
      https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
    dnf clean all

# curl replaces the preinstalled curl-minimal, hence --allowerasing
RUN dnf install -y --allowerasing \
    bzip2 \
    ca-certificates \
    curl \
    gnupg2 \
    wget \
    git \
    nano \
    tzdata \
    unzip \
    vim-minimal \
    openssh-clients \
    less \
    texlive-xetex \
    texlive-collection-fontsrecommended \
    texlive-cm-super \
    texlive-dvipng \
    xclip \
    gcc \
    gcc-c++ \
    make \
    ffmpeg \
    shadow-utils \
    which \
    procps-ng \
    file \
    iproute && \
    dnf clean all

# R pre-requisites
RUN dnf install -y \
    dejavu-sans-fonts \
    dejavu-serif-fonts \
    dejavu-sans-mono-fonts \
    gcc-gfortran \
    lftp \
    unrar \
    jq-devel \
    libjpeg-turbo-devel \
    protobuf-devel \
    protobuf-compiler \
    udunits2-devel \
    geos-devel \
    gdal-devel \
    lbzip2 \
    proj-devel \
    netcdf-devel \
    netcdf \
    hdf5-devel \
    python3 \
    python3-devel \
    python3-pip \
    sqlite-devel \
    gdal \
    proj \
    python3-gdal && \
    dnf clean all

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal C_INCLUDE_PATH=/usr/include/gdal

# tools
RUN dnf install -y htop libarchive && dnf clean all

# install other Python versions, to chose from
# python3.9 is the system python3, 3.11 and 3.12 come from AppStream
RUN dnf install -y \
    python3.11 python3.11-devel python3.11-pip \
    python3.12 python3.12-devel python3.12-pip && \
    dnf clean all

# nice to have
# # 3.7, 3.8, 3.10, 3.13 and 3.14 are not packaged for EL9, build them from source
# ARG PYTHON_SOURCE_VERSIONS="3.7.17 3.8.20 3.10.18 3.13.7 3.14.0"
# RUN dnf install -y \
#     openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel \
#     readline-devel ncurses-devel gdbm-devel libuuid-devel tk-devel && \
#     for v in ${PYTHON_SOURCE_VERSIONS}; do \
#       cd /tmp && \
#       curl -fsSL https://www.python.org/ftp/python/${v}/Python-${v}.tgz | tar xz && \
#       cd Python-${v} && \
#       ./configure --prefix=/usr/local --enable-shared --with-ensurepip=install \
#         LDFLAGS="-Wl,-rpath,/usr/local/lib" && \
#       make -j"$(nproc)" && \
#       make altinstall && \
#       cd /tmp && rm -rf Python-${v} || exit 1; \
#     done && \
#     dnf clean all

RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
    tee /etc/yum.repos.d/nvidia-container-toolkit.repo

ENV NVIDIA_CONTAINER_TOOLKIT_VERSION=1.19.1-1
RUN dnf install -y \
      nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION} && \
    dnf clean all

# install pipx
RUN dnf install -y pipx nvtop && dnf clean all

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV SHELL=/bin/bash

COPY ./python_version_noconda.sh /start.sh

ARG GID=900
ARG UID=900

RUN groupadd -g $GID slurm && useradd -r -u $UID -g slurm -s /sbin/nologin slurm

CMD ["sh", "./start.sh"]
