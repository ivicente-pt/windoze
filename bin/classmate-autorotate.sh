#!/bin/bash

MONITOR="DSI-1"
TOUCH="Goodix Capacitive TouchScreen"
#TOUCH=14
USER_NAME=$(loginctl list-users --no-legend | awk '{print $2}' | head -n1)
[[ -z "$USER_NAME" ]] && USER_NAME=$(who | cut -d' ' -f1 | head -n1)
export DISPLAY=:0
export XAUTHORITY=/home/$USER_NAME/.Xauthority

rotate() {
    sleep 0.5
    case "$1" in
        normal)
            xrandr --output "$MONITOR" --rotate inverted
            xinput set-prop "$TOUCH" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
        ;;
        bottom-up)
            xrandr --output "$MONITOR" --rotate normal
            xinput set-prop "$TOUCH" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
        ;;
        right-up)
            xrandr --output "$MONITOR" --rotate right
            xinput set-prop "$TOUCH" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
        ;;
        left-up)
            xrandr --output "$MONITOR" --rotate left
            xinput set-prop "$TOUCH" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
        ;;
    esac
    sleep 1
}

monitor-sensor | stdbuf -oL grep --line-buffered "orientation changed" | while read -r line; do
    DIRECTION="${line##* }"
    rotate "$DIRECTION"
done

