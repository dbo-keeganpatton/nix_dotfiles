#!/bin/bash

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
           --insensitive)

case "$CHOSEN" in
    "$LOCK")     hyprlock ;;
    "$SLEEP")    systemctl suspend ;;
    "$REBOOT")   systemctl reboot ;;
    "$SHUTDOWN") systemctl poweroff ;;
esac
