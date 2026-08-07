#!/usr/bin/env bash
set -euo pipefail

VNC_PORT=${VNC_PORT:-5901}
NO_VNC_PORT=${NO_VNC_PORT:-6901}
VNC_COL_DEPTH=${VNC_COL_DEPTH:-24}
VNC_RESOLUTION=${VNC_RESOLUTION:-1920x1080}

# TigerVNC now expects its password file in ~/.config/tigervnc/passwd.
# Keep the legacy ~/.vnc/passwd path as a fallback for older images/setups.
PASSWD_PATH="$HOME/.config/tigervnc/passwd"
LEGACY_PASSWD_PATH="$HOME/.vnc/passwd"

mkdir -p "$HOME/.config/tigervnc"

if [ ! -f "$PASSWD_PATH" ] && [ -f "$LEGACY_PASSWD_PATH" ]; then
    PASSWD_PATH="$LEGACY_PASSWD_PATH"
fi

# check if the password file exists if not, exit with error
if [ ! -f "$PASSWD_PATH" ]; then
    echo "VNC password file not found: $PASSWD_PATH" >&2
    echo "Please mount the password file into the container at $HOME/.config/tigervnc/passwd" >&2
    echo "make sure the password has at least 6 characters and is not empty" >&2
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

# mkdir -p "$HOME/.vnc"
# PASSWD_PATH="$HOME/.vnc/passwd"
# rm -f "$PASSWD_PATH"
# echo $(<"/vnc_password.txt") | vncpasswd -f > "$PASSWD_PATH"
# chmod 600 "$PASSWD_PATH"

DISPLAY=:$((VNC_PORT - 5900))
export DISPLAY

# Provide xstartup so TigerVNC uses xfce4 rather than its own default WM.
# cat > "$HOME/.config/tigervnc/xstartup" <<'XSTARTUP'
# #!/usr/bin/env bash
# unset SESSION_MANAGER
# unset DBUS_SESSION_BUS_ADDRESS
# # dbus-launch is required; without it xfce4-session exits immediately in a container
# eval "$(dbus-launch --sh-syntax --exit-with-session)"
# exec /usr/bin/startxfce4
# XSTARTUP
#chmod 755 "$HOME/.config/tigervnc/xstartup"

# Clear stale glycin loader cache; binaries extracted from a previous image build will fail
rm -rf "$HOME/.cache/glycin"

# Regenerate gdk-pixbuf loaders cache so paths match the running container
GDK_LOADERS_CACHE=/tmp/gdk-pixbuf-loaders.cache
gdk-pixbuf-query-loaders > "$GDK_LOADERS_CACHE" 2>/dev/null || true

cat > "$HOME/.config/tigervnc/xstartup" <<XSTARTUP
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# glycin uses bubblewrap sandboxing which fails inside Singularity
export GLYCIN_SANDBOX_MECHANISM=none
export GDK_PIXBUF_MODULE_FILE=$GDK_LOADERS_CACHE
# dbus-launch is required; without it xfce4-session exits immediately in a container
eval "\$(dbus-launch --sh-syntax --exit-with-session)"
exec /usr/bin/startxfce4
XSTARTUP
chmod 755 "$HOME/.config/tigervnc/xstartup"



# TigerVNC and ICE won't create these dirs when running as non-root (Singularity/HPC)
mkdir -p /tmp/.X11-unix /tmp/.ICE-unix
chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix

vncserver -kill "$DISPLAY" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_kill.log" 2>&1 || true
vncserver "$DISPLAY" -depth "$VNC_COL_DEPTH" -geometry "$VNC_RESOLUTION" \
    -xstartup "$HOME/.config/tigervnc/xstartup" \
    > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_vnc_startup.log" 2>&1

websockify -D --web="$VNC_ROOT/novnc" "$NO_VNC_PORT" "127.0.0.1:$VNC_PORT" > "$LOG_FILE_DIR/${LOG_FILE_PREFIX}_no_vnc_startup.log" 2>&1

echo "VNC available at http://$(hostname):${NO_VNC_PORT}"
while true; do
    sleep 1000
done