#!/usr/bin/env bash
set -euo pipefail

# picom.sh v1.1 2026-04-07

xfconf-query -c xfwm4 -p /general/use_compositing -s false -t bool --create
PICOM="${PICOM:-0}"
[[ "$PICOM" -ne 1 ]] && exit 0
killall -q picom || true
sleep 3
picom -b --config /opt/aevh/conf/picom/picom.conf
