FROM ubuntu:bionic

RUN apt-get update && apt-get -y install gnupg ca-certificates wget apt-transport-https; \
    gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF; \
	gpg -a --export 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF | apt-key add -; \
    echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" > /etc/apt/sources.list.d/mono-official-stable.list; \
    wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb; \
    dpkg -i packages-microsoft-prod.deb; \
    rm packages-microsoft-prod.deb;

RUN ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
apt-get install -y tzdata  && dpkg-reconfigure -f noninteractive tzdata

RUN apt-get update 
RUN apt-get install -y mono-runtime gtk-sharp2 mono-devel dotnet-sdk-3.1 sqlite3 libcanberra-gtk-module libwebkitgtk-1.0-0

RUN mkdir -p /resource
ADD ApsimSetup6139.deb /resource

RUN dpkg --force-depends -i /resource/ApsimSetup6139.deb

COPY runapsim.sh /usr/local/bin/runapsim
RUN chmod 555 /usr/local/bin/runapsim

RUN addgroup mygroup && adduser --disabled-password --gecos "" --ingroup mygroup myuser
USER myuser

WORKDIR /apsim

CMD ["/bin/bash"]