FROM rocker/geospatial:4.6.1
RUN apt-get update -qq && apt-get -y install \
apt-utils \
libjpeg-dev \
libudunits2-dev \
gsl-bin \
libgsl-dev \
libglpk-dev \
libglpk40

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
   htop \
   ca-certificates \
   curl \
   gnupg2

RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update

ENV NVIDIA_CONTAINER_TOOLKIT_VERSION=1.20.1-1
RUN apt-get install -y \
      nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

RUN apt-get update --yes && apt-get install --yes pipx


# clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*



