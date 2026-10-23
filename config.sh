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

# Optional network and battery indicators.
NETWORK_INTERVAL=15
BATTERY_INTERVAL=30
BATTERY_WARNING=25
BATTERY_CRITICAL=10

DBAR_NETWORK_WIFI_ICON='󰖩'
DBAR_NETWORK_ETHERNET_ICON='󰈀'
DBAR_NETWORK_OFFLINE_ICON='󰤮'
DBAR_BATTERY_ICON='󰁹'
DBAR_BATTERY_CHARGING_ICON='󰂄'

# ALSA playback and root filesystem usage.
VOLUME_INTERVAL=5
DISK_INTERVAL=60
DISK_WARNING=75
DISK_CRITICAL=90
DBAR_VOLUME_ICON=''
DBAR_VOLUME_MUTED_ICON='󰖁'
DBAR_DISK_ICON='󰋊'
DBAR_ALSA_DEVICE='default'

# CPU temperature (degrees Celsius) and BlueZ Bluetooth status.
TEMPERATURE_INTERVAL=10
TEMPERATURE_WARNING=70
TEMPERATURE_CRITICAL=85
DBAR_TEMPERATURE_ICON=''

BLUETOOTH_INTERVAL=15
DBAR_BLUETOOTH_ON_ICON='󰂯'
DBAR_BLUETOOTH_OFF_ICON='󰂲'

# Display brightness (hidden without a readable backlight device).
BRIGHTNESS_INTERVAL=5
DBAR_BRIGHTNESS_ICON='󰃠'

# USB storage disks and configured CUPS printers.
USB_INTERVAL=10
DBAR_USB_ICON=''

PRINTER_INTERVAL=30
DBAR_PRINTER_ICON=''

# Active modules in display order; an empty list displays nothing.
# Override this value in the untracked config.local.sh file.
DBAR_MODULES='cpu memory network battery brightness volume disk temperature bluetooth usb printers clock'
