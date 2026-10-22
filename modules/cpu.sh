#!/bin/sh

CPU_PERCENT=-1
CPU_LAST_TOTAL=0
CPU_LAST_IDLE=0

# Measure CPU activity between readings without requiring mpstat.
update_cpu() {
    read -r label user nice system idle iowait irq softirq steal rest < /proc/stat

    iowait=${iowait:-0}
    irq=${irq:-0}
    softirq=${softirq:-0}
    steal=${steal:-0}

    cpu_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    cpu_idle=$((idle + iowait))

    if [ "$CPU_LAST_TOTAL" -gt 0 ]; then
        cpu_delta=$((cpu_total - CPU_LAST_TOTAL))
        idle_delta=$((cpu_idle - CPU_LAST_IDLE))

        if [ "$cpu_delta" -gt 0 ]; then
            CPU_PERCENT=$(((cpu_delta - idle_delta) * 100 / cpu_delta))
        fi
    fi

    CPU_LAST_TOTAL=$cpu_total
    CPU_LAST_IDLE=$cpu_idle
}
