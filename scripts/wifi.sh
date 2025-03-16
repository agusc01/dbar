#!/bin/sh

if grep -xq 'up' /sys/class/net/w*/operstate 2>/dev/null; then
    wifi_icon="  "
    # ssid=$(iw dev | grep ssid | xargs | sed 's/ssid//')
elif grep -xq 'down' /sys/class/net/w*/operstate 2>/dev/null; then
    grep -xq '0x1003' /sys/class/net/w*/flags && wifi_icon="📡 " || wifi_icon="   "
fi

echo "$ssid $wifi_icon"
