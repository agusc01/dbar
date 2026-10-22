#!/bin/sh

# Color control bytes supported by the agusc01/dwm statuscolors patch.
DBAR_NORMAL=$(printf '\001')
DBAR_RED=$(printf '\003')
DBAR_ORANGE=$(printf '\004')
DBAR_GREEN=$(printf '\016')

# Return a control byte for a usage percentage.
dbar_color_for() {
    usage=$1
    warning=$2
    critical=$3

    if [ "$DBAR_COLOR_MODE" = "off" ]; then
        printf '%s' "$DBAR_NORMAL"
    elif [ "$usage" -ge "$critical" ]; then
        printf '%s' "$DBAR_RED"
    elif [ "$usage" -ge "$warning" ]; then
        printf '%s' "$DBAR_ORANGE"
    else
        printf '%s' "$DBAR_GREEN"
    fi
}
