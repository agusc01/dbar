#!/bin/sh

# Optional local overrides, never tracked by Git.
# Copy this file to config.local.sh to customize your bar.

# The order of these lines controls the order in dbar.
# Comment out a line to disable a module (no polling or clickable area).
DBAR_MODULES=''

DBAR_MODULES="$DBAR_MODULES cpu"
DBAR_MODULES="$DBAR_MODULES memory"
DBAR_MODULES="$DBAR_MODULES network"
DBAR_MODULES="$DBAR_MODULES battery"
DBAR_MODULES="$DBAR_MODULES brightness"
DBAR_MODULES="$DBAR_MODULES volume"
DBAR_MODULES="$DBAR_MODULES disk"
DBAR_MODULES="$DBAR_MODULES temperature"
DBAR_MODULES="$DBAR_MODULES bluetooth"
DBAR_MODULES="$DBAR_MODULES usb"
DBAR_MODULES="$DBAR_MODULES printers"
DBAR_MODULES="$DBAR_MODULES clock"

# Optional per-module sampling overrides (seconds, 1 to 86400).
# CPU_INTERVAL=10
# BLUETOOTH_INTERVAL=30
