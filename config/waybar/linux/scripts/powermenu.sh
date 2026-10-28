#!/usr/bin/env bash

choice=$(printf "Lock\nLogout\nPoweroff" | wofi --dmenu)

case "$choice" in
  Lock) hyprlock ;;
  Logout) hyprctl dispatch exit ;;
  Poweroff) systemctl poweroff ;;
esac
