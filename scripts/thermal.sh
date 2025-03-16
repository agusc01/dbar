#!/bin/sh

# Define the thermal zone for the CPU (adjust if necessary)
thermal_zone="/sys/class/thermal/thermal_zone0/temp"

# Check if the temperature file exists
if [ ! -f "$thermal_zone" ]; then
    # echo "Cannot access the CPU thermal zone: $thermal_zone"
    echo "X °C"
    exit 1
fi

# Read the CPU temperature
temperature=$(cat "$thermal_zone")

# Convert the temperature from millidegrees Celsius to degrees Celsius
temperature_c=$(echo "scale=1; $temperature / 1000" | bc)

# Print the CPU temperature
echo "$temperature_c °C"
