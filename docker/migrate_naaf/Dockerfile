# Prepare the environment to use Migrate on HPC cluster with openmpi
# a program for population genetic inference
# see:
# Beerli, P., Mashayekhi, S., Sadeghi, M., Khodaei, M., and Shaw, K. (2019) 
# Population genetic inference with Migrate. Current Protocols in Bioinformatics, 68(1):e87. 
# https://currentprotocols.onlinelibrary.wiley.com/doi/abs/10.1002/cpbi.87.

# downloaded from https://peterbeerli.com

FROM ubuntu:24.04

# install build tools
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    bzip2 \
    ca-certificates \
    wget \
    unzip \
    less \
    build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG MIGRATE_VERSION=migrate-5.0.6

ENV DOWNLOAD=/download
ENV MPI_DIR=/opt/ompi
RUN mkdir -p ${DOWNLOAD}
ENV USER=mpitest
ENV GROUP=mpitest
ENV HOME=/home/$USER
ENV PATH="${MPI_DIR}/bin:${HOME}/.local/bin:${PATH}"

WORKDIR ${DOWNLOAD}

# Download OPENMPI from https://www.open-mpi.org/software/ompi/v5.0/
RUN wget https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.6.tar.gz

# verify the SHA256 checksum for openmpi-5.0.6.tar.gz
ENV SHA256=1d6dd41f6b53c00db23b40e56733d16a996fa743957ef8add8e117feffd92689
RUN echo "${SHA256} ${DOWNLOAD}/openmpi-5.0.6.tar.gz" | sha256sum -c -

# fail build if checksum is invalid
RUN if [ $? -ne 0 ]; then exit 1; fi

# Download migrade from https://peterbeerli.com/migrate-html5/download_version4/ 
# note: the download link is not stable, please check the latest version from the website
RUN wget https://peterbeerli.com/migrate-html5/download_version4/${MIGRATE_VERSION}.src.tar.gz

# install missing libraries
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    libgsl-dev \
    libgslcblas0 \
    python3 python3-dev python3-pip \
    gcc gfortran binutils 
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install clang compiler
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    clang \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LD_LIBRARY_PATH="${MPI_DIR}/lib"
ENV CC=clang
ENV CXX=clang++

# compile openmpi
RUN mkdir -p ${DOWNLOAD}/openmpi-5.0.6
RUN tar -xvzf openmpi-5.0.6.tar.gz
WORKDIR ${DOWNLOAD}/openmpi-5.0.6
RUN ./configure --prefix=$MPI_DIR 
RUN make
RUN make install

# compile migrate
WORKDIR ${DOWNLOAD}
RUN mkdir -p ${MIGRATE_VERSION}
RUN tar -xvzf ${MIGRATE_VERSION}.src.tar.gz
WORKDIR ${DOWNLOAD}/${MIGRATE_VERSION}/src

# compile migrate
RUN ./configure
RUN make clean
RUN make mpis



RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    python3.12-venv \
    python3.12-dev \
    pipx \
    python3-mpi4py \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN groupadd -r ${GROUP} \
    && useradd -r -g ${GROUP} ${USER} \
    && mkdir -p $HOME \
    && chown -R ${USER}:${GROUP} $HOME
USER ${USER}
WORKDIR ${HOME}


