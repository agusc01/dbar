#!/bin/sh

BRIGHTNESS_PERCENT=-1

# Read the first usable backlight, hiding the segment when none is available.
update_brightness() {
    BRIGHTNESS_PERCENT=-1
    brightness_sys_root=${DBAR_SYS_ROOT:-/sys}

    for brightness_device in "$brightness_sys_root"/class/backlight/*; do
        [ -d "$brightness_device" ] || continue
        [ -r "$brightness_device/max_brightness" ] || continue

        IFS= read -r brightness_max < "$brightness_device/max_brightness" || continue
        case "$brightness_max" in
            ''|*[!0-9]*) continue ;;
        esac

        # Prefer the effective hardware level; fall back to the requested level.
        for brightness_file in actual_brightness brightness; do
            [ -r "$brightness_device/$brightness_file" ] || continue
            IFS= read -r brightness_current \
                < "$brightness_device/$brightness_file" || continue
            case "$brightness_current" in
                ''|*[!0-9]*) continue ;;
            esac

            # awk keeps leading zeros decimal and avoids shell integer overflow.
            brightness_percent=$(awk -v value="$brightness_current" \
                -v maximum="$brightness_max" '
                BEGIN {
                    if (maximum + 0 <= 0) exit 1
                    percentage = 100 * (value + 0) / (maximum + 0)
                    if (percentage > 100) percentage = 100
                    printf "%d\n", int(percentage + 0.5)
                }
            ') || continue

            BRIGHTNESS_PERCENT=$brightness_percent
            return 0
        done
    done

    return 0
}
