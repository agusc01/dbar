#!/bin/sh

# Get total and used RAM in MB
total_ram=$(free -m | awk 'NR==2{print $2}')
used_ram=$(free -m | awk 'NR==2{print $3}')

# Calculate the percentage of RAM used
# percent_used_ram=$(echo "scale=2; ($used_ram / $total_ram) * 100" | bc)

# Convert used RAM to GB with one decimal point
used_ram_gb=$(echo "scale=3; $used_ram / 1024" | bc)

# Get total and used swap memory in MB
total_swap=$(free -m | awk 'NR==3{print $2}')
used_swap=$(free -m | awk 'NR==3{print $3}')

# Calculate the percentage of swap used
# percent_used_swap=$(echo "scale=2; ($used_swap / $total_swap) * 100" | bc)

# Convert used swap to GB with one decimal point
used_swap_gb=$(echo "scale=3; $used_swap / 1024" | bc)

# Initialize memory icon
# memory_icon='⭐' # Star icon
memory_icon=''

# Print the output using echo
# echo "[${memory_icon} ${used_ram_gb}GB - ${percent_used_ram%.*}% | ${used_swap_gb}GB - ${percent_used_swap%.*}%]"
echo "${memory_icon} ${used_ram_gb}GB | ${used_swap_gb}GB"
