FROM zalfrpm/python3.10:no_conda_10

# Install dependencies
ENV DEFAULTHOME=/headless 
ENV TERM=xterm 
ENV VNC_COL_DEPTH=24 
ENV VNC_RESOLUTION=1280x1024 
ENV VNC_PW=vncpassword 
ENV VNC_VIEW_ONLY=false


RUN apt-get update --yes
# Install Xfce GUI
RUN apt-get install -y supervisor xfce4 xfce4-terminal xterm
RUN apt-get purge -y pm-utils xscreensaver*
# install tightvnc server
RUN apt-get install -y tigervnc-standalone-server 

RUN apt-get install -y vim net-tools locales
#Install noVNC - HTML5 based VNC viewer
RUN apt-get -y install novnc python3-websockify python3-numpy
# Install firefox
RUN apt-get install -y firefox
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install root_painter UI
RUN wget https://github.com/Abe404/root_painter/releases/download/0.2.27/RootPainter_0.2.27_Ubuntu22.deb -O RootPainter_0.2.27_Ubuntu22.deb
RUN dpkg --add-architecture i386
RUN dpkg -i RootPainter_0.2.27_Ubuntu22.deb
RUN rm RootPainter_0.2.27_Ubuntu22.deb

RUN mkdir -p $DEFAULTHOME
COPY ./xfce/. $DEFAULTHOME
COPY ./vnc_startup.sh /opt/vnc_startup.sh
COPY ./wm_startup.sh /opt/wm_startup.sh

RUN chmod -R 777 $DEFAULTHOME
RUN chmod -R 777 /opt/vnc_startup.sh
RUN chmod -R 777 /opt/wm_startup.sh

CMD ["sh", "./start.sh"]