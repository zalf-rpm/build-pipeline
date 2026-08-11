#!/usr/bin/env bash
set -euo pipefail

VNC_PORT=${VNC_PORT:-5901}
NO_VNC_PORT=${NO_VNC_PORT:-6901}
VNC_COL_DEPTH=${VNC_COL_DEPTH:-24}
VNC_RESOLUTION=${VNC_RESOLUTION:-1920x1080}

# TigerVNC now expects its password file in ~/.config/tigervnc/passwd.
PASSWD_PATH="$HOME/.config/tigervnc/passwd"
mkdir -p "$HOME/.config/tigervnc"

# check if the password file exists if not, exit with error
if [ ! -f "$PASSWD_PATH" ]; then
    echo "VNC password file not found: $PASSWD_PATH" >&2
    echo "Please mount the password file into the container at $HOME/.config/tigervnc/passwd" >&2
    echo "make sure the password has at least 6 characters and is not empty" >&2
    exit 1
fi

# xstartup folder
VNC_ROOT="$HOME/.vnc"
mkdir -p "$VNC_ROOT"
# log folder
LOG_FILE_DIR="$HOME/vnc_logs"
mkdir -p "$LOG_FILE_DIR"
LOG_FILE_PREFIX=$(date +%s)

NO_VNC_DIR="$HOME/novnc"
if [ ! -d "$NO_VNC_DIR" ]; then
    mkdir -p "$NO_VNC_DIR"
    cp -r /usr/share/novnc/* "$NO_VNC_DIR"
    ln -sf "$NO_VNC_DIR/vnc_lite.html" "$NO_VNC_DIR/index.html"
fi

mkdir -p /tmp/.X11-unix
mkdir -p /tmp/.ICE-unix

# TODO: get more info about they DISPLAY
# DISPLAY=:$((VNC_PORT - 5900))
# export DISPLAY
DISPLAY=:1

cat > "$VNC_ROOT/xstartup" <<'XSTARTUP'
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XSTARTUP
chmod +x "$VNC_ROOT/xstartup"


vncserver -kill "$DISPLAY" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_kill.log" 2>&1 || true
vncserver "$DISPLAY" -depth "$VNC_COL_DEPTH" -geometry "$VNC_RESOLUTION" \
    -xstartup "$VNC_ROOT/xstartup" \
    -localhost yes \
    > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_startup.log" 2>&1

websockify -D --web="$NO_VNC_DIR" "$NO_VNC_PORT" "localhost:$VNC_PORT" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_no_vnc_startup.log" 2>&1

echo "VNC available at http://$(hostname):${NO_VNC_PORT}"
while true; do
    sleep 1000
done