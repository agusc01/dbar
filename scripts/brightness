#!/bin/sh

b=$(xrandr --verbose | grep -i brightness | awk '{print $2 *100}' | bc)

echo "☀️$b%"
