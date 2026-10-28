#!/usr/bin/env bash
command -v nvidia-smi >/dev/null 2>&1 || exit 0
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits \
| awk '{print "󰢮 " $1 "% " $2 "°C"}'
