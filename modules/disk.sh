#!/bin/sh

DISK_PERCENT=-1

# Read usage of the filesystem containing the root directory.
update_disk() {
    DISK_PERCENT=-1

    disk_df=${DBAR_DF:-df}
    command -v "$disk_df" >/dev/null 2>&1 || return 0

    disk_value=$(LC_ALL=C "$disk_df" -P / 2>/dev/null | awk '
        NR == 2 {
            used = $5
            sub(/%$/, "", used)
            if (used ~ /^[0-9]+$/) print used
        }
    ') || return 0
    case "$disk_value" in
        ''|*[!0-9]*) return 0 ;;
    esac
    [ "$disk_value" -le 100 ] || return 0
    DISK_PERCENT=$disk_value
}
