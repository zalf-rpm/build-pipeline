#!/usr/bin/env bash
set -euo pipefail

VNC_PORT=${VNC_PORT:-5901}
NO_VNC_PORT=${NO_VNC_PORT:-6901}
VNC_COL_DEPTH=${VNC_COL_DEPTH:-24}
VNC_RESOLUTION=${VNC_RESOLUTION:-1920x1080}

if [ -z "${VNC_PW:-}" ]; then
    echo "VNC_PW must be set" >&2
    exit 1
fi

VNC_ROOT="$HOME/vnc"
LOG_FILE_DIR="$VNC_ROOT/vnc_logs"
mkdir -p "$LOG_FILE_DIR"
LOG_FILE_PREFIX=$(date +%s)

if [ ! -d "$VNC_ROOT/novnc" ]; then
    mkdir -p "$VNC_ROOT"
    cp -r /usr/share/novnc "$VNC_ROOT/novnc"
    ln -sf "$VNC_ROOT/novnc/vnc_lite.html" "$VNC_ROOT/novnc/index.html"
fi

mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"
rm -f "$PASSWD_PATH"
echo "$VNC_PW" | vncpasswd -f > "$PASSWD_PATH"
chmod 600 "$PASSWD_PATH"

DISPLAY=:$((VNC_PORT - 5900))
export DISPLAY

vncserver -kill "$DISPLAY" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_kill.log" 2>&1 || true
vncserver "$DISPLAY" -depth "$VNC_COL_DEPTH" -geometry "$VNC_RESOLUTION" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_startup.log" 2>&1

/opt/wm_startup.sh > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_wm_startup.log" 2>&1

websockify -D --web="$VNC_ROOT/novnc" "$NO_VNC_PORT" "localhost:$VNC_PORT" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_no_vnc_startup.log" 2>&1

echo "VNC available at http://$(hostname):${NO_VNC_PORT}"
while true; do
    sleep 1000
done