FROM rocker/geospatial:4.4.1
RUN apt-get update -qq && apt-get -y install \
apt-utils \
libjpeg-dev \
libudunits2-dev \
gsl-bin \
libgsl-dev \
libglpk-dev \
libglpk40

RUN apt-get update -qq && apt-get -y install \
 htop \
 gnupg 


RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update && apt-get install -y nvidia-container-toolkit

# clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*



