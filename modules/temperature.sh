#!/bin/sh

TEMPERATURE_C=-1

# Interpret CPU sensor readings in millidegrees Celsius.
read_cpu_temperature() {
    [ -r "$1" ] || return 1
    IFS= read -r temperature_raw < "$1" || return 1

    case "$temperature_raw" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$temperature_raw" -ge 1000 ] || return 1
    [ "$temperature_raw" -le 125000 ] || return 1

    TEMPERATURE_C=$(((temperature_raw + 500) / 1000))
    return 0
}

# Use only identifiable CPU sensors; hide the segment if none is available.
update_temperature() {
    TEMPERATURE_C=-1
    temperature_sys_root=${DBAR_SYS_ROOT:-/sys}

    for sensor in "$temperature_sys_root"/class/hwmon/hwmon*; do
        [ -r "$sensor/name" ] || continue
        IFS= read -r sensor_name < "$sensor/name" || continue

        case "$sensor_name" in
            coretemp|k10temp|zenpower|peci_cputemp|cpu_thermal|soc_thermal)
                ;;
            *) continue ;;
        esac

        for input in "$sensor"/temp*_input; do
            if read_cpu_temperature "$input"; then
                return 0
            fi
        done
    done

    # Some devices expose the CPU only through thermal zones.
    for zone in "$temperature_sys_root"/class/thermal/thermal_zone*; do
        [ -r "$zone/type" ] || continue
        IFS= read -r zone_type < "$zone/type" || continue

        case "$zone_type" in
            x86_pkg_temp|cpu-thermal|cpu_thermal|soc-thermal|soc_thermal)
                ;;
            *) continue ;;
        esac

        if read_cpu_temperature "$zone/temp"; then
            return 0
        fi
    done

    return 0
}
