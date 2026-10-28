#!/usr/bin/env bash
# Set DOTFILES_WEATHER_LOCATION for a fixed location; otherwise use IP location.
location=${DOTFILES_WEATHER_LOCATION:-}
case "$location" in *[!A-Za-z0-9_-]*) exit 0 ;; esac
curl --fail --silent --show-error --max-time 5 "https://wttr.in/$location?format=%t" 2>/dev/null || true
