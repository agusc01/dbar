#!/bin/sh

USB_COUNT=0

# Count USB storage disks, not partitions, using their physical sysfs path.
update_usb() {
    USB_COUNT=0
    usb_sys_root=${DBAR_SYS_ROOT:-/sys}

    for usb_disk in "$usb_sys_root"/block/*; do
        [ -r "$usb_disk/size" ] || continue

        IFS= read -r usb_size < "$usb_disk/size" || continue
        case "$usb_size" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$usb_size" -gt 0 ] || continue

        # Exclude optical drives when SCSI device type information exists.
        if [ -r "$usb_disk/device/type" ]; then
            IFS= read -r usb_type < "$usb_disk/device/type" || continue
            [ "$usb_type" = 0 ] || continue
        fi

        # A resolved block-device path has a /usbN/ ancestor for USB storage.
        usb_path=$(readlink -f "$usb_disk" 2>/dev/null) || continue
        case "$usb_path" in
            */usb[0-9]*/*)
                USB_COUNT=$((USB_COUNT + 1))
                ;;
        esac
    done
}
