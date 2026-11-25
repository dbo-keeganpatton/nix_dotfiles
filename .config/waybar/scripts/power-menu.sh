#!/usr/bin/env bash

LOCK="󰌾  Lock"
SLEEP="󰒲  Sleep"
REBOOT="󰑐  Reboot"
SHUTDOWN="󰐥  Shutdown"

CHOSEN=$(printf "%s\n%s\n%s\n%s" "$LOCK" "$SLEEP" "$REBOOT" "$SHUTDOWN" \
    | wofi --dmenu \
           --prompt "" \
           --width 180 \
           --height 170 \
           --lines 4 \
           --no-actions \
           --insensitive \
           --location top_left \
           --xoffset 8 \
           --yoffset 28 \
           --style ~/.config/wofi/power-menu-style.css)

case "$CHOSEN" in
    "$LOCK")     hyprlock ;;
    "$SLEEP")    systemctl suspend ;;
    "$REBOOT")   systemctl reboot ;;
    "$SHUTDOWN") systemctl poweroff ;;
esac
