#!/bin/sh

NETWORK_CONNECTED=0
NETWORK_ICON=""

# Inspect the default route without assuming an interface name or network daemon.
update_network() {
    NETWORK_CONNECTED=0
    NETWORK_ICON=$DBAR_NETWORK_OFFLINE_ICON

    network_proc_root=${DBAR_PROC_ROOT:-/proc}
    network_sys_root=${DBAR_SYS_ROOT:-/sys}
    network_interface=""

    if [ -r "$network_proc_root/net/route" ]; then
        network_interface=$(awk '
            NR > 1 && $2 == "00000000" && $8 == "00000000" {
                if (!found || $7 + 0 < best_metric) {
                    best_metric = $7 + 0
                    best_interface = $1
                    found = 1
                }
            }
            END { if (found) print best_interface }
        ' "$network_proc_root/net/route")
    fi

    # IPv6-only hosts have no default route in /proc/net/route.
    if [ -z "$network_interface" ] &&
       [ -r "$network_proc_root/net/ipv6_route" ]; then
        network_interface=$(awk '
            $1 ~ /^0+$/ && $2 == "00" {
                print $NF
                exit
            }
        ' "$network_proc_root/net/ipv6_route")
    fi

    [ -n "$network_interface" ] || return 0
    [ -d "$network_sys_root/class/net/$network_interface" ] || return 0

    # No carrier means the chosen interface does not have a physical link.
    if [ -r "$network_sys_root/class/net/$network_interface/carrier" ]; then
        IFS= read -r network_carrier \
            < "$network_sys_root/class/net/$network_interface/carrier" || return 0
        [ "$network_carrier" = 1 ] || return 0
    fi

    NETWORK_CONNECTED=1
    NETWORK_ICON=$DBAR_NETWORK_ETHERNET_ICON

    if [ -d "$network_sys_root/class/net/$network_interface/wireless" ] ||
       [ -e "$network_sys_root/class/net/$network_interface/phy80211" ]; then
        NETWORK_ICON=$DBAR_NETWORK_WIFI_ICON
    fi
}
