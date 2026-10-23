#!/bin/sh
set -eu

# Exercise CPU thermal sensors and BlueZ state with simulated hardware.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME"
cp -v "$source_repository/dbar" "$DBAR_HOME/dbar" >/dev/null
cp -v "$source_repository/config.sh" "$DBAR_HOME/config.sh" >/dev/null
cp -Rv "$source_repository/modules" "$DBAR_HOME/modules" >/dev/null
cp -Rv "$source_repository/lib" "$DBAR_HOME/lib" >/dev/null
export DBAR_HOME

DBAR_SYS_ROOT="$fixture/sys"
DBAR_PROC_ROOT="$fixture/proc"
DBAR_BLUETOOTHCTL="$fixture/bin/bluetoothctl"
DBAR_AMIXER=/nonexistent/dbar-amixer
DBAR_DF=/nonexistent/dbar-df
export DBAR_SYS_ROOT DBAR_PROC_ROOT DBAR_BLUETOOTHCTL DBAR_AMIXER DBAR_DF
DBAR_LPSTAT=/nonexistent/dbar-lpstat
export DBAR_LPSTAT

mkdir -p "$fixture/bin"
mkdir -p "$DBAR_SYS_ROOT/class/hwmon/hwmon0"
mkdir -p "$DBAR_SYS_ROOT/class/thermal"
mkdir -p "$DBAR_SYS_ROOT/class/bluetooth"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply"
mkdir -p "$DBAR_SYS_ROOT/class/net"
mkdir -p "$DBAR_PROC_ROOT/net"
printf '%s\n' 'Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT' \
    > "$DBAR_PROC_ROOT/net/route"

cat > "$DBAR_BLUETOOTHCTL" <<'MOCK'
#!/bin/sh
[ "$1" = -t ] && [ "$2" = 2 ] || exit 1
shift 2
case "$1" in
    show)
        case "${DBAR_TEST_BLUETOOTH:-off}" in
            off) printf 'Controller 00:11:22:33:44:55\n\tPowered: no\n' ;;
            on0|on2|on3) printf 'Controller 00:11:22:33:44:55\n\tPowered: yes\n' ;;
            *) exit 1 ;;
        esac
        ;;
    devices)
        [ "$2" = Connected ] || exit 1
        case "${DBAR_TEST_BLUETOOTH:-off}" in
            on2|on3)
                printf 'Device AA:BB:CC:DD:EE:01 Keyboard\n'
                printf 'Device AA:BB:CC:DD:EE:02 Headphones\n'
                if [ "$DBAR_TEST_BLUETOOTH" = on3 ]; then
                    printf 'Device AA:BB:CC:DD:EE:03 Mouse\n'
                fi
                ;;
            on0) : ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$DBAR_BLUETOOTHCTL"

. "$DBAR_HOME/config.sh"
. "$DBAR_HOME/modules/temperature.sh"
. "$DBAR_HOME/modules/bluetooth.sh"

# Unknown hardware must not leak into the CPU temperature indicator.
update_temperature
[ "$TEMPERATURE_C" -eq -1 ] ||
    { echo 'Error: Temperature should be hidden without a sensor.' >&2; exit 1; }

printf 'acpitz\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/name"
printf '48000\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
update_temperature
[ "$TEMPERATURE_C" -eq -1 ] ||
    { echo 'Error: Unrelated ACPI sensor was mistaken for CPU temperature.' >&2; exit 1; }

printf 'coretemp\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/name"
update_temperature
[ "$TEMPERATURE_C" -eq 48 ] ||
    { echo 'Error: CPU hwmon temperature should be 48 degrees.' >&2; exit 1; }

for degrees in 78000 91000; do
    printf '%s\n' "$degrees" > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
    update_temperature
    [ "$TEMPERATURE_C" -eq $((degrees / 1000)) ] ||
        { echo 'Error: CPU hwmon temperature was not converted.' >&2; exit 1; }
done

printf '900000\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
update_temperature
[ "$TEMPERATURE_C" -eq -1 ] ||
    { echo 'Error: Impossible sensor reading was not rejected.' >&2; exit 1; }

mkdir -p "$DBAR_SYS_ROOT/class/thermal/thermal_zone0"
printf 'x86_pkg_temp\n' > "$DBAR_SYS_ROOT/class/thermal/thermal_zone0/type"
printf '49000\n' > "$DBAR_SYS_ROOT/class/thermal/thermal_zone0/temp"
update_temperature
[ "$TEMPERATURE_C" -eq 49 ] ||
    { echo 'Error: CPU thermal zone fallback failed.' >&2; exit 1; }

# A missing adapter has no icon even if bluetoothctl is installed.
update_bluetooth
[ "$BLUETOOTH_PRESENT" -eq 0 ] && [ "$BLUETOOTH_CONNECTED" -eq 0 ] ||
    { echo 'Error: Missing Bluetooth hardware should be hidden.' >&2; exit 1; }

mkdir -p "$DBAR_SYS_ROOT/class/bluetooth/hci0"
DBAR_TEST_BLUETOOTH=off; export DBAR_TEST_BLUETOOTH
update_bluetooth
[ "$BLUETOOTH_PRESENT" -eq 1 ] && [ "$BLUETOOTH_POWERED" -eq 0 ] ||
    { echo 'Error: Powered-off Bluetooth adapter was not detected.' >&2; exit 1; }

DBAR_TEST_BLUETOOTH=on0; export DBAR_TEST_BLUETOOTH
update_bluetooth
[ "$BLUETOOTH_POWERED" -eq 1 ] && [ "$BLUETOOTH_CONNECTED" -eq 0 ] ||
    { echo 'Error: Zero Bluetooth connections incorrectly counted.' >&2; exit 1; }

DBAR_TEST_BLUETOOTH=on2; export DBAR_TEST_BLUETOOTH
update_bluetooth
[ "$BLUETOOTH_CONNECTED" -eq 2 ] ||
    { echo 'Error: Expected two connected Bluetooth devices.' >&2; exit 1; }

DBAR_TEST_BLUETOOTH=on3; export DBAR_TEST_BLUETOOTH
update_bluetooth
[ "$BLUETOOTH_CONNECTED" -eq 3 ] ||
    { echo 'Error: Expected three connected Bluetooth devices.' >&2; exit 1; }

DBAR_TEST_BLUETOOTH=failed; export DBAR_TEST_BLUETOOTH
update_bluetooth
[ "$BLUETOOTH_PRESENT" -eq 1 ] && [ "$BLUETOOTH_POWERED" -eq 0 ] &&
[ "$BLUETOOTH_CONNECTED" -eq 0 ] ||
    { echo 'Error: Unavailable BlueZ must not retain stale connections.' >&2; exit 1; }

# Test the complete bar, its separators, and color controls.
printf '48000\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
DBAR_TEST_BLUETOOTH=on2; export DBAR_TEST_BLUETOOTH
printf 'off\n' > "$DBAR_HOME/color-mode"
active=$(sh "$DBAR_HOME/dbar" preview)
case "$active" in
    *"$DBAR_TEMPERATURE_ICON 48°$DBAR_SEPARATOR$DBAR_BLUETOOTH_ON_ICON 2$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: Bluetooth count and temperature rendering are incorrect.' >&2; exit 1 ;;
esac
[ "$(printf '%s\n' "$active" | awk -F '[|]' '{print NF}')" -eq 6 ] ||
    { echo 'Error: Expected six visible segments with temperature and Bluetooth.' >&2; exit 1; }
if printf '%s' "$active" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome status contains control bytes.' >&2
    exit 1
fi

DBAR_TEST_BLUETOOTH=on0; export DBAR_TEST_BLUETOOTH
zero=$(sh "$DBAR_HOME/dbar" preview)
case "$zero" in
    *"$DBAR_BLUETOOTH_ON_ICON$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: Bluetooth with zero connections must show icon only.' >&2; exit 1 ;;
esac
case "$zero" in
    *"$DBAR_BLUETOOTH_ON_ICON 0"*)
        echo 'Error: Bluetooth must not display zero.' >&2
        exit 1 ;;
esac

DBAR_TEST_BLUETOOTH=off; export DBAR_TEST_BLUETOOTH
printf 'on\n' > "$DBAR_HOME/color-mode"
red=$(printf '\003')
orange=$(printf '\004')
off=$(sh "$DBAR_HOME/dbar" preview)
case "$off" in
    *"$red$DBAR_BLUETOOTH_OFF_ICON"*) ;;
    *) echo 'Error: Bluetooth off should display a red icon.' >&2; exit 1 ;;
esac

printf '78000\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
warm=$(sh "$DBAR_HOME/dbar" preview)
case "$warm" in
    *"$orange$DBAR_TEMPERATURE_ICON 78°"*) ;;
    *) echo 'Error: Hot CPU should display an orange temperature.' >&2; exit 1 ;;
esac

printf '91000\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/temp1_input"
hot=$(sh "$DBAR_HOME/dbar" preview)
case "$hot" in
    *"$red$DBAR_TEMPERATURE_ICON 91°"*) ;;
    *) echo 'Error: Critical CPU temperature should appear in red.' >&2; exit 1 ;;
esac

# On machines without hardware, neither segment nor extra separators appear.
printf 'acpitz\n' > "$DBAR_SYS_ROOT/class/hwmon/hwmon0/name"
printf 'other\n' > "$DBAR_SYS_ROOT/class/thermal/thermal_zone0/type"
rmdir "$DBAR_SYS_ROOT/class/bluetooth/hci0"
printf 'off\n' > "$DBAR_HOME/color-mode"
absent=$(sh "$DBAR_HOME/dbar" preview)
[ "$(printf '%s\n' "$absent" | awk -F '[|]' '{print NF}')" -eq 4 ] ||
    { echo 'Error: Missing hardware left extra separators.' >&2; exit 1; }

printf '%s\n' 'Temperature and Bluetooth module tests passed.'
