#!/bin/sh

# Define the CPU icon (you can change it if desired)
cpu_icon="🖥️" # You can use other icons like "💻" or "⚙️"

# Get the CPU usage using top
cpu_usage=$(mpstat 1 1 | awk '/Average:/ {print $5}' | tail -1)

# Print the CPU usage with the icon
echo "$cpu_icon $cpu_usage %"
