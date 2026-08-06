#!/usr/bin/env bash
set -e

mkdir -p "$HOME/vnc/vnc_logs"
xset -dpms || true
xset s noblank || true
xset s off || true

/usr/bin/startxfce4 --replace > "$HOME/vnc/vnc_logs/wm.log" 2>&1 &
sleep 1
cat "$HOME/vnc/vnc_logs/wm.log" || true