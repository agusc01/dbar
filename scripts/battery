#!/bin/sh

# Read the battery information
battery_info=$(acpi)

# Extract the percentage and state of the battery
battery_percentage=$(echo $battery_info | awk '{print $4}' | tr -d ',')
battery_state=$(echo "$battery_info" | awk '{print $3}' | tr -d ',')

# Initialize a variable for the icon
battery_icon='❤️' # Red heart icon

# Determine the symbol based on the battery state
if [ "$battery_state" = 'Charging' ]; then
    battery_symbol='▲' # Triangle up for charging
elif [ "$battery_state" = 'Discharging' ]; then
    battery_symbol='▼' # Triangle down for discharging
elif [ "$battery_state" = 'Full' ]; then
    battery_symbol='✔' # Symbol for full battery
fi

# Print the output using echo
echo "$battery_icon $battery_percentage $battery_symbol"
