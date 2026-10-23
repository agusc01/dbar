#!/bin/sh

BLUETOOTH_PRESENT=0
BLUETOOTH_POWERED=0
BLUETOOTH_CONNECTED=0

# Detect the default Bluetooth controller and count currently connected devices.
update_bluetooth() {
    BLUETOOTH_PRESENT=0
    BLUETOOTH_POWERED=0
    BLUETOOTH_CONNECTED=0

    bluetooth_sys_root=${DBAR_SYS_ROOT:-/sys}
    bluetooth_command=${DBAR_BLUETOOTHCTL:-bluetoothctl}

    for bluetooth_adapter in "$bluetooth_sys_root"/class/bluetooth/hci*; do
        [ -d "$bluetooth_adapter" ] || continue
        BLUETOOTH_PRESENT=1
        break
    done

    [ "$BLUETOOTH_PRESENT" -eq 1 ] || return 0
    command -v "$bluetooth_command" >/dev/null 2>&1 || return 0

    # The timeout avoids blocking the bar when D-Bus or BlueZ does not respond.
    bluetooth_info=$("$bluetooth_command" -t 2 show 2>/dev/null) || return 0
    case "$bluetooth_info" in
        *"Powered: yes"*) BLUETOOTH_POWERED=1 ;;
        *) return 0 ;;
    esac

    # Only count active links, never all paired or remembered devices.
    connected_devices=$("$bluetooth_command" -t 2 devices Connected 2>/dev/null) ||
        return 0

    BLUETOOTH_CONNECTED=$(printf '%s\n' "$connected_devices" | awk '
        $1 == "Device" && NF >= 3 { count++ }
        END { print count + 0 }
    ')
}
