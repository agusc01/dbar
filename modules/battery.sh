#!/bin/sh

BATTERY_PERCENT=-1
BATTERY_STATUS=Unknown
BATTERY_ICON=""

# Read the first available battery; hide the segment if none is present.
update_battery() {
    BATTERY_PERCENT=-1
    BATTERY_STATUS=Unknown
    BATTERY_ICON=""

    battery_sys_root=${DBAR_SYS_ROOT:-/sys}

    for battery_path in "$battery_sys_root"/class/power_supply/*; do
        [ -r "$battery_path/type" ] || continue
        IFS= read -r battery_type < "$battery_path/type" || continue
        [ "$battery_type" = Battery ] || continue

        # Detachable batteries can be listed while physically absent.
        if [ -r "$battery_path/present" ]; then
            IFS= read -r battery_present < "$battery_path/present" || continue
            [ "$battery_present" = 1 ] || continue
        fi

        [ -r "$battery_path/capacity" ] || continue
        IFS= read -r battery_value < "$battery_path/capacity" || continue
        case "$battery_value" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$battery_value" -le 100 ] || continue

        BATTERY_PERCENT=$battery_value

        if [ -r "$battery_path/status" ]; then
            IFS= read -r BATTERY_STATUS \
                < "$battery_path/status" || BATTERY_STATUS=Unknown
        fi

        BATTERY_ICON=$DBAR_BATTERY_ICON
        if [ "$BATTERY_STATUS" = Charging ]; then
            BATTERY_ICON=$DBAR_BATTERY_CHARGING_ICON
        fi
        break
    done
}
