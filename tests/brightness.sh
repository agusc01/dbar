#!/bin/sh
set -eu

# Exercise backlight sampling and full status rendering with simulated sysfs.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME"
cp "$source_repository/dbar" "$DBAR_HOME/dbar"
cp "$source_repository/config.sh" "$DBAR_HOME/config.sh"
cp -R "$source_repository/modules" "$DBAR_HOME/modules"
cp -R "$source_repository/lib" "$DBAR_HOME/lib"
export DBAR_HOME

DBAR_SYS_ROOT="$fixture/sys"
DBAR_PROC_ROOT="$fixture/proc"
DBAR_AMIXER=/nonexistent/dbar-amixer
DBAR_DF=/nonexistent/dbar-df
export DBAR_SYS_ROOT DBAR_PROC_ROOT DBAR_AMIXER DBAR_DF
DBAR_LPSTAT=/nonexistent/dbar-lpstat
export DBAR_LPSTAT

mkdir -p "$DBAR_SYS_ROOT/class/backlight"
mkdir -p "$DBAR_SYS_ROOT/class/net"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply"
mkdir -p "$DBAR_SYS_ROOT/class/bluetooth"
mkdir -p "$DBAR_SYS_ROOT/class/hwmon"
mkdir -p "$DBAR_SYS_ROOT/class/thermal"
mkdir -p "$DBAR_PROC_ROOT/net"
printf '%s\n' 'Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT' \
    > "$DBAR_PROC_ROOT/net/route"

. "$DBAR_HOME/config.sh"
. "$DBAR_HOME/modules/brightness.sh"

update_brightness
[ "$BRIGHTNESS_PERCENT" -eq -1 ] ||
    { echo 'Error: Missing backlight must be hidden.' >&2; exit 1; }

backlight="$DBAR_SYS_ROOT/class/backlight/backlight0"
mkdir -p "$backlight"

update_brightness
[ "$BRIGHTNESS_PERCENT" -eq -1 ] ||
    { echo 'Error: Missing maximum must be hidden.' >&2; exit 1; }

printf '400\n' > "$backlight/max_brightness"
printf '300\n' > "$backlight/brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 75 ] ||
    { echo 'Error: Requested backlight should produce 75 percent.' >&2; exit 1; }

# Prefer the actual display brightness over the requested value.
printf '100\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 25 ] ||
    { echo 'Error: Actual brightness must take precedence.' >&2; exit 1; }

# Malformed actual readings fall back to the requested brightness.
printf 'invalid\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 75 ] ||
    { echo 'Error: Invalid actual brightness must use fallback.' >&2; exit 1; }

printf '0\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 0 ] ||
    { echo 'Error: Zero brightness is valid.' >&2; exit 1; }

printf '500\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 100 ] ||
    { echo 'Error: Brightness above maximum must be clamped.' >&2; exit 1; }

# Leading zeros must be decimal, not shell octal numbers.
printf '0400\n' > "$backlight/max_brightness"
printf '0100\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 25 ] ||
    { echo 'Error: Leading-zero brightness is incorrect.' >&2; exit 1; }

printf '3\n' > "$backlight/max_brightness"
printf '2\n' > "$backlight/actual_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 67 ] ||
    { echo 'Error: Fractional brightness should round to 67 percent.' >&2; exit 1; }

printf '0\n' > "$backlight/max_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq -1 ] ||
    { echo 'Error: Zero maximum brightness must be hidden.' >&2; exit 1; }

printf 'bad\n' > "$backlight/max_brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq -1 ] ||
    { echo 'Error: Invalid maximum brightness must be hidden.' >&2; exit 1; }

# An invalid first device must not block a second usable backlight.
second="$DBAR_SYS_ROOT/class/backlight/backlight1"
mkdir -p "$second"
printf '100\n' > "$second/max_brightness"
printf '10\n' > "$second/brightness"
update_brightness
[ "$BRIGHTNESS_PERCENT" -eq 10 ] ||
    { echo 'Error: Second valid backlight must be detected.' >&2; exit 1; }

# The full bar adds the segment without extra pipes or color control bytes.
printf 'off\n' > "$DBAR_HOME/color-mode"
displayed=$(sh "$DBAR_HOME/dbar" preview)
case "$displayed" in
    *"$DBAR_BRIGHTNESS_ICON 10%$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: Incorrect brightness placement in status.' >&2; exit 1 ;;
esac
[ "$(printf '%s\n' "$displayed" | awk -F '[|]' '{print NF}')" -eq 5 ] ||
    { echo 'Error: Expected five segments with brightness.' >&2; exit 1; }
if printf '%s' "$displayed" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome brightness contains control bytes.' >&2
    exit 1
fi

# Hide the segment and its separator when no readable device remains.
rm -R "$DBAR_SYS_ROOT/class/backlight/backlight0"
rm -R "$DBAR_SYS_ROOT/class/backlight/backlight1"
hidden=$(sh "$DBAR_HOME/dbar" preview)
case "$hidden" in
    *"$DBAR_BRIGHTNESS_ICON"*)
        echo 'Error: Missing backlight must not render an icon.' >&2
        exit 1 ;;
esac
[ "$(printf '%s\n' "$hidden" | awk -F '[|]' '{print NF}')" -eq 4 ] ||
    { echo 'Error: Missing backlight left an extra separator.' >&2; exit 1; }

printf '%s\n' 'Brightness module tests passed.'
