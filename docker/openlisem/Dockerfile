# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install dependencies
# Based on compile_lisem_linux.txt
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    cmake-gui \
    git \
    libboost-all-dev \
    libncurses5-dev \
    libpython3-dev \
    libxerces-c-dev \
    libxml2 \
    libxml2-utils \
    libxslt1-dev \
    python3-numpy \
    qt6-base-dev \
    python3-docopt \
    openssl \
    libglu1-mesa-dev \
    freeglut3-dev \
    mesa-common-dev \
    gdal-bin \
    libgdal-dev \
    libcurl4-openssl-dev \
    libqt6svg6-dev \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install specific QWT branch as required by openLISEM
# -----------------------------------------------------------------------------

# Clone the repository
RUN git clone -b qwt-multiaxes https://git.code.sf.net/p/qwt/git /usr/src/qwt

WORKDIR /usr/src/qwt

# Configure QWT 
# Disable QwtSvg as suggested in compile instructions to avoid potential errors
# Use flexible regex for whitespace
RUN sed -i 's/QWT_CONFIG.*+=.*QwtSvg/#QWT_CONFIG     += QwtSvg/g' qwtconfig.pri

# Compile and install QWT using Qt6 qmake
RUN /usr/lib/qt6/bin/qmake qwt.pro && \
    make -j$(nproc) && \
    make install

# -----------------------------------------------------------------------------
# Build openLISEM
# -----------------------------------------------------------------------------

WORKDIR /usr/src

# Checkout the repository (main_C branch)
RUN git clone -b main_C https://github.com/vjetten/openlisem.git openlisem

# Create build directory
WORKDIR /usr/src/openlisem/build

# Configure and compile
# We dynamically find the QWT installation directory in /usr/local
# Export NIX_QWT so CMake can pick it up from the environment
RUN QWT_DIR=$(ls -d /usr/local/qwt-*) && \
    echo "Found QWT at $QWT_DIR" && \
    export NIX_QWT=$QWT_DIR && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Make the executable available globally (optional)
# RUN ln -s /usr/src/openlisem/build/Lisem /usr/local/bin/Lisem

CMD ["/bin/bash"]
