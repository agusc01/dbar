#!/bin/sh

# Select which modules are active, and validate before starting the status loop.
# The user's local configuration is intentionally never tracked by Git.
load_module_config() {
    . "$DBAR_HOME/config.sh"

    if [ -L "$DBAR_HOME/config.local.sh" ]; then
        echo 'Error: config.local.sh must be a regular file, not a symlink.' >&2
        return 1
    fi
    if [ -e "$DBAR_HOME/config.local.sh" ]; then
        if [ ! -f "$DBAR_HOME/config.local.sh" ]; then
            echo 'Error: config.local.sh is not a regular file.' >&2
            return 1
        fi
        . "$DBAR_HOME/config.local.sh"
    fi

    # An empty list is valid: it clears the status bar without polling.
    module_seen=' '
    for configured_module in $DBAR_MODULES; do
        case "$configured_module" in
            cpu|memory|network|battery|brightness|volume|disk|temperature|bluetooth|usb|printers|clock) ;;
            *)
                echo "Error: Unknown dbar module: $configured_module" >&2
                return 1 ;;
        esac

        case "$module_seen" in
            *" $configured_module "*)
                echo "Error: Duplicate dbar module: $configured_module" >&2
                return 1 ;;
        esac
        module_seen="$module_seen$configured_module "

        module_interval_for "$configured_module"
        case "$module_interval" in
            ''|0*|*[!0-9]*)
                echo "Error: Invalid interval for $configured_module: $module_interval" >&2
                return 1 ;;
        esac
        if [ "${#module_interval}" -gt 5 ] || [ "$module_interval" -gt 86400 ]; then
            echo "Error: Interval for $configured_module must be between 1 and 86400." >&2
            return 1
        fi
    done
}

# Resolve the refresh interval from a trusted, known module name.
module_interval_for() {
    case "$1" in
        cpu) module_interval=$CPU_INTERVAL ;;
        memory) module_interval=$MEMORY_INTERVAL ;;
        network) module_interval=$NETWORK_INTERVAL ;;
        battery) module_interval=$BATTERY_INTERVAL ;;
        brightness) module_interval=$BRIGHTNESS_INTERVAL ;;
        volume) module_interval=$VOLUME_INTERVAL ;;
        disk) module_interval=$DISK_INTERVAL ;;
        temperature) module_interval=$TEMPERATURE_INTERVAL ;;
        bluetooth) module_interval=$BLUETOOTH_INTERVAL ;;
        usb) module_interval=$USB_INTERVAL ;;
        printers) module_interval=$PRINTER_INTERVAL ;;
        clock) module_interval=$CLOCK_INTERVAL ;;
    esac
}

# Never evaluate module names as commands or accept arbitrary script names.
update_module() {
    case "$1" in
        cpu) update_cpu ;;
        memory) update_memory ;;
        network) update_network ;;
        battery) update_battery ;;
        brightness) update_brightness ;;
        volume) update_volume ;;
        disk) update_disk ;;
        temperature) update_temperature ;;
        bluetooth) update_bluetooth ;;
        usb) update_usb ;;
        printers) update_printers ;;
        clock) update_clock ;;
    esac
}

# Initialize only modules that are enabled in the configured list.
update_active_modules() {
    for sampled_module in $DBAR_MODULES; do
        update_module "$sampled_module"
    done
}

# Sample only enabled modules when their independent interval is due.
update_due_modules() {
    sampling_second=$1
    for sampled_module in $DBAR_MODULES; do
        module_interval_for "$sampled_module"
        if [ $((sampling_second % module_interval)) -eq 0 ]; then
            update_module "$sampled_module"
        fi
    done
}
