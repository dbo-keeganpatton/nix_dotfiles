#!/usr/bin/env bash

LAPTOP="eDP-1"

EXT=$(hyprctl monitors -j | jq -r '.[] | select(.name != "'"$LAPTOP"'") | .name' | head -1)

if [ -n "$EXT" ]; then
    # Move every workspace that lives on the laptop screen to the external monitor
    hyprctl workspaces -j | jq -r '.[] | select(.monitor == "'"$LAPTOP"'") | .id' | while read -r ws; do
        hyprctl dispatch moveworkspacetomonitor "$ws" "$EXT"
    done
    hyprctl keyword monitor "$LAPTOP, disable"
    loginctl lock-session
else
    systemctl suspend
fi
