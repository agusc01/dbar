#!/bin/sh

# Build untagged preview text and clickable root-window status.
# Arguments: one-character ID, visible text and optional color.
append_status_segment() {
    [ -n "$2" ] || return 0

    if [ -n "$output" ]; then
        output="${output}${DBAR_SEPARATOR}"
        tagged_output="${tagged_output}${DBAR_SEPARATOR}"
    fi

    status_text=$2
    if [ "$DBAR_COLOR_MODE" = on ] && [ -n "$3" ]; then
        status_text="${3}${2}${DBAR_NORMAL}"
    fi
    output="${output}${status_text}"
    tagged_output="${tagged_output}@{${1}}${status_text}"
}

render_cpu() {
    cpu_value="--"
    cpu_color=""
    if [ "$CPU_PERCENT" -ge 0 ]; then
        cpu_value="${CPU_PERCENT}%"
        cpu_color=$(dbar_color_for "$CPU_PERCENT" "$CPU_WARNING" "$CPU_CRITICAL")
    fi
    append_status_segment c "$DBAR_CPU_ICON $cpu_value" "$cpu_color"
}

render_memory() {
    memory_color=$(dbar_color_for "$MEMORY_PERCENT" "$MEMORY_WARNING" "$MEMORY_CRITICAL")
    append_status_segment m "$DBAR_MEMORY_ICON ${MEMORY_PERCENT}%" "$memory_color"
}

render_network() {
    network_color=$DBAR_RED
    if [ "$NETWORK_CONNECTED" -eq 1 ]; then
        network_color=$DBAR_GREEN
    fi
    append_status_segment n "$NETWORK_ICON" "$network_color"
}

render_battery() {
    [ "$BATTERY_PERCENT" -ge 0 ] || return 0

    battery_color=$DBAR_GREEN
    if [ "$BATTERY_STATUS" != Charging ] && [ "$BATTERY_STATUS" != Full ]; then
        if [ "$BATTERY_PERCENT" -le "$BATTERY_CRITICAL" ]; then
            battery_color=$DBAR_RED
        elif [ "$BATTERY_PERCENT" -le "$BATTERY_WARNING" ]; then
            battery_color=$DBAR_ORANGE
        fi
    fi
    append_status_segment b "$BATTERY_ICON ${BATTERY_PERCENT}%" "$battery_color"
}

render_brightness() {
    if [ "$BRIGHTNESS_PERCENT" -ge 0 ]; then
        append_status_segment l "$DBAR_BRIGHTNESS_ICON ${BRIGHTNESS_PERCENT}%" ""
    fi
}

render_volume() {
    [ "$VOLUME_PERCENT" -ge 0 ] || return 0

    if [ "$VOLUME_MUTED" -eq 1 ]; then
        append_status_segment v "$DBAR_VOLUME_MUTED_ICON" "$DBAR_ORANGE"
    else
        append_status_segment v "$DBAR_VOLUME_ICON ${VOLUME_PERCENT}%" "$DBAR_GREEN"
    fi
}

render_disk() {
    if [ "$DISK_PERCENT" -ge 0 ]; then
        disk_color=$(dbar_color_for "$DISK_PERCENT" "$DISK_WARNING" "$DISK_CRITICAL")
        append_status_segment d "$DBAR_DISK_ICON ${DISK_PERCENT}%" "$disk_color"
    fi
}

render_temperature() {
    if [ "$TEMPERATURE_C" -ge 0 ]; then
        temperature_color=$(dbar_color_for "$TEMPERATURE_C" "$TEMPERATURE_WARNING" "$TEMPERATURE_CRITICAL")
        append_status_segment t "$DBAR_TEMPERATURE_ICON ${TEMPERATURE_C}°" "$temperature_color"
    fi
}

render_bluetooth() {
    [ "$BLUETOOTH_PRESENT" -eq 1 ] || return 0

    if [ "$BLUETOOTH_POWERED" -eq 1 ]; then
        bluetooth_text=$DBAR_BLUETOOTH_ON_ICON
        if [ "$BLUETOOTH_CONNECTED" -gt 0 ]; then
            bluetooth_text="$bluetooth_text $BLUETOOTH_CONNECTED"
        fi
        append_status_segment h "$bluetooth_text" "$DBAR_GREEN"
    else
        append_status_segment h "$DBAR_BLUETOOTH_OFF_ICON" "$DBAR_RED"
    fi
}

render_usb() {
    if [ "$USB_COUNT" -gt 0 ]; then
        append_status_segment u "$DBAR_USB_ICON $USB_COUNT" ""
    fi
}

render_printers() {
    [ "$PRINTER_COUNT" -gt 0 ] || return 0

    printer_text=$DBAR_PRINTER_ICON
    if [ "$PRINTER_JOBS" -gt 0 ]; then
        printer_text="$printer_text $PRINTER_JOBS"
    fi
    append_status_segment p "$printer_text" ""
}

render_clock() {
    append_status_segment k "$DBAR_CLOCK_ICON $CLOCK" ""
}

# Render in configuration order. Hidden hardware adds no empty separators.
render_module() {
    case "$1" in
        cpu) render_cpu ;;
        memory) render_memory ;;
        network) render_network ;;
        battery) render_battery ;;
        brightness) render_brightness ;;
        volume) render_volume ;;
        disk) render_disk ;;
        temperature) render_temperature ;;
        bluetooth) render_bluetooth ;;
        usb) render_usb ;;
        printers) render_printers ;;
        clock) render_clock ;;
    esac
}

render_bar() {
    load_color_mode
    output=""
    tagged_output=""

    for displayed_module in $DBAR_MODULES; do
        render_module "$displayed_module"
    done
}
