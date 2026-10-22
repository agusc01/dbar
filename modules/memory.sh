#!/bin/sh

MEMORY_PERCENT=0

# Calculate memory utilization from available physical memory.
update_memory() {
    MEMORY_PERCENT=$(awk '
        /^MemTotal:/ { total = $2 }
        /^MemAvailable:/ { available = $2 }
        END {
            if (total > 0) {
                printf "%.0f", 100 * (total - available) / total
            } else {
                print 0
            }
        }
    ' /proc/meminfo)
}
