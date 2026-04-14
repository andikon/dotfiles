#!/usr/bin/env bash
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits \
| awk '{print "󰢮 " $1 "% " $2 "°C"}'
