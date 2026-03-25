#!/usr/bin/env bash
set -euo pipefail

# picom.sh v1.1 2026-03-24

xfconf-query -c xfwm4 -p /general/use_compositing -s false --create
[[ "${PICOM:-0}" == "1" ]] && { sleep 3; picom -b --config /opt/aevh/etc/picom.conf; }
