#!/usr/bin/env bash
set -euo pipefail

# picom.sh v1.0 2025-12-14

xfconf-query -c xfwm4 -p /general/use_compositing -s false --create
if [[ "$PICOM" -eq "1" ]]; then
    sleep 3
    picom --config /opt/aevh/etc/picom.conf
fi
