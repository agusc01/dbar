#!/bin/sh
set -eu

# Exercise interface and battery detection with isolated /proc and /sys fixtures.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

# Keep color-mode changes inside the fixture, never the user's checkout.
DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME"
cp -v "$source_repository/dbar" "$DBAR_HOME/dbar" >/dev/null
cp -v "$source_repository/config.sh" "$DBAR_HOME/config.sh" >/dev/null
cp -Rv "$source_repository/modules" "$DBAR_HOME/modules" >/dev/null
cp -Rv "$source_repository/lib" "$DBAR_HOME/lib" >/dev/null
export DBAR_HOME

. "$DBAR_HOME/config.sh"
. "$DBAR_HOME/modules/network.sh"
. "$DBAR_HOME/modules/battery.sh"

DBAR_PROC_ROOT="$fixture/proc"
DBAR_SYS_ROOT="$fixture/sys"
export DBAR_PROC_ROOT DBAR_SYS_ROOT

# This fixture only tests network and battery; disable unrelated modules.
DBAR_AMIXER=/nonexistent/dbar-amixer
DBAR_DF=/nonexistent/dbar-df
export DBAR_AMIXER DBAR_DF

mkdir -p "$DBAR_PROC_ROOT/net"
mkdir -p "$DBAR_SYS_ROOT/class/net/enp0s3"
mkdir -p "$DBAR_SYS_ROOT/class/net/wlan0/wireless"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply"

cat > "$DBAR_PROC_ROOT/net/route" <<'ROUTES'
Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT
enp0s3 00000000 0101A8C0 0003 0 0 100 00000000 0 0 0
wlan0 00000000 0101A8C0 0003 0 0 20 00000000 0 0 0
ROUTES
printf '1\n' > "$DBAR_SYS_ROOT/class/net/wlan0/carrier"
printf '1\n' > "$DBAR_SYS_ROOT/class/net/enp0s3/carrier"

update_network
[ "$NETWORK_CONNECTED" = 1 ] && [ "$NETWORK_ICON" = "$DBAR_NETWORK_WIFI_ICON" ] ||
    { echo 'Error: Did not detect routed Wi-Fi interface.' >&2; exit 1; }

printf '0\n' > "$DBAR_SYS_ROOT/class/net/wlan0/carrier"
update_network
[ "$NETWORK_CONNECTED" = 0 ] && [ "$NETWORK_ICON" = "$DBAR_NETWORK_OFFLINE_ICON" ] ||
    { echo 'Error: Did not detect missing carrier.' >&2; exit 1; }

cat > "$DBAR_PROC_ROOT/net/route" <<'ROUTES'
Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT
enp0s3 00000000 0101A8C0 0003 0 0 100 00000000 0 0 0
ROUTES
update_network
[ "$NETWORK_CONNECTED" = 1 ] && [ "$NETWORK_ICON" = "$DBAR_NETWORK_ETHERNET_ICON" ] ||
    { echo 'Error: Did not detect routed Ethernet interface.' >&2; exit 1; }

cat > "$DBAR_PROC_ROOT/net/route" <<'ROUTES'
Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT
ROUTES
printf '00000000000000000000000000000000 00 00000000000000000000000000000000 00 00000000000000000000000000000000 00000000 00000000 00000000 00000001 enp0s3\n' > "$DBAR_PROC_ROOT/net/ipv6_route"
update_network
[ "$NETWORK_CONNECTED" = 1 ] && [ "$NETWORK_ICON" = "$DBAR_NETWORK_ETHERNET_ICON" ] ||
    { echo 'Error: IPv6 default route not detected.' >&2; exit 1; }

: > "$DBAR_PROC_ROOT/net/ipv6_route"
update_network
[ "$NETWORK_CONNECTED" = 0 ] ||
    { echo 'Error: Route-free interface should be offline.' >&2; exit 1; }

update_battery
[ "$BATTERY_PERCENT" = -1 ] ||
    { echo 'Error: Missing battery was not hidden.' >&2; exit 1; }

mkdir -p "$DBAR_SYS_ROOT/class/power_supply/AC"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply/BAT0"
printf 'Mains\n' > "$DBAR_SYS_ROOT/class/power_supply/AC/type"
printf 'Battery\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/type"
printf '1\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/present"
printf '40\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/capacity"
printf 'Charging\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/status"

update_battery
[ "$BATTERY_PERCENT" = 40 ] && [ "$BATTERY_ICON" = "$DBAR_BATTERY_CHARGING_ICON" ] ||
    { echo 'Error: Charging battery not detected.' >&2; exit 1; }

# Preview uses the same source modules and renderer as the live status bar.
cat > "$DBAR_PROC_ROOT/net/route" <<'ROUTES'
Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT
wlan0 00000000 0101A8C0 0003 0 0 20 00000000 0 0 0
ROUTES
printf '1\n' > "$DBAR_SYS_ROOT/class/net/wlan0/carrier"

printf 'off\n' > "$DBAR_HOME/color-mode"
plain=$(sh "$DBAR_HOME/dbar" preview)
case "$plain" in
    *"$DBAR_NETWORK_WIFI_ICON$DBAR_SEPARATOR$DBAR_BATTERY_CHARGING_ICON 40%$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*)
        ;;
    *)
        echo 'Error: Incorrect compact status segment order.' >&2
        exit 1
        ;;
esac
[ "$(printf '%s\n' "$plain" | awk -F '[|]' '{print NF}')" -eq 5 ] ||
    { echo 'Error: Expected exactly five visible status segments.' >&2; exit 1; }
if printf '%s' "$plain" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome preview contains control bytes.' >&2
    exit 1
fi

printf 'on\n' > "$DBAR_HOME/color-mode"
colored=$(sh "$DBAR_HOME/dbar" preview)
if ! printf '%s' "$colored" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Colored preview has no color control bytes.' >&2
    exit 1
fi

# A removed battery must also remove the adjacent separator.
printf '0\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/present"
printf 'off\n' > "$DBAR_HOME/color-mode"
without_battery=$(sh "$DBAR_HOME/dbar" preview)
[ "$(printf '%s\n' "$without_battery" | awk -F '[|]' '{print NF}')" -eq 4 ] ||
    { echo 'Error: Battery-free preview has an extra segment.' >&2; exit 1; }
case "$without_battery" in
    *"$DBAR_BATTERY_ICON"*|*"$DBAR_BATTERY_CHARGING_ICON"*)
        echo 'Error: Absent battery is still visible.' >&2
        exit 1
        ;;
esac

# Test the severity threshold without requiring a physical low battery.
printf '1\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/present"
printf '8\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/capacity"
printf 'Discharging\n' > "$DBAR_SYS_ROOT/class/power_supply/BAT0/status"
printf 'on\n' > "$DBAR_HOME/color-mode"
critical=$(sh "$DBAR_HOME/dbar" preview)
red=$(printf '\003')
case "$critical" in
    *"$red$DBAR_BATTERY_ICON 8%"*) ;;
    *)
        echo 'Error: Critical battery was not highlighted in red.' >&2
        exit 1
        ;;
esac

printf 'on\n' > "$DBAR_HOME/color-mode"
printf '%s\n' 'Network and battery module tests passed.'
