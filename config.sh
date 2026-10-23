#!/bin/sh

# Module sampling intervals (seconds).
CPU_INTERVAL=5
MEMORY_INTERVAL=5
CLOCK_INTERVAL=30

# Usage percentage thresholds.
CPU_WARNING=70
CPU_CRITICAL=90
MEMORY_WARNING=75
MEMORY_CRITICAL=90

# Compact Nerd Font indicators. Customize these glyphs or the separator here.
DBAR_CPU_ICON=''
DBAR_MEMORY_ICON='󰍛'
DBAR_CLOCK_ICON=''
DBAR_SEPARATOR=' | '
