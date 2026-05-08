#!/bin/bash

MONITOR="DSI-1"
#TOUCH="Goodix Capacitive TouchScreen id=14"
TOUCH=14
USER=$(who | cut -d' ' -f1 | sort | uniq | head -n1)
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority

rotate() {
    sleep 1
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

monitor-sensor | while read -r line; do
    if [[ $line == *"orientation changed"* ]]; then
        DIRECTION=$(echo $line | awk '{print $NF}')
        rotate "$DIRECTION"
    fi
done

