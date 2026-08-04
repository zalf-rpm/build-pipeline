FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1920x1080 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false

# Optional mirror override for CI builds.
# Example: --build-arg APT_MIRROR=mirror.hetzner.com
ARG APT_MIRROR=archive.ubuntu.com

RUN set -eux; \
    if [ -f /etc/apt/sources.list ]; then \
        sed -i "s|http://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" /etc/apt/sources.list; \
    fi; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
        sed -i "s|http://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g" /etc/apt/sources.list.d/ubuntu.sources; \
    fi; \
    apt-get update -o Acquire::Retries=5; \
    apt-get install -y --no-install-recommends \
        locales \
        ca-certificates \
        dbus-x11 \
        xfce4 \
        xfce4-goodies \
        tigervnc-standalone-server \
        tigervnc-common \
        novnc \
        websockify \
        xterm \
        x11-xserver-utils \
        procps; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/. /opt/
RUN chmod 755 /opt/wm_startup.sh /opt/vnc_startup-ubuntu-26.sh

EXPOSE 5901 6901
ENTRYPOINT ["/opt/vnc_startup-ubuntu-26.sh"]

