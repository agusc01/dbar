#!/bin/sh
set -eu

# Test USB storage paths and CUPS queues without real hardware or services.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME" "$fixture/bin"
cp "$source_repository/dbar" "$DBAR_HOME/dbar"
cp "$source_repository/config.sh" "$DBAR_HOME/config.sh"
cp -R "$source_repository/modules" "$DBAR_HOME/modules"
cp -R "$source_repository/lib" "$DBAR_HOME/lib"
export DBAR_HOME

DBAR_SYS_ROOT="$fixture/sys"
DBAR_PROC_ROOT="$fixture/proc"
DBAR_AMIXER=/nonexistent/dbar-amixer
DBAR_DF=/nonexistent/dbar-df
DBAR_LPSTAT="$fixture/bin/lpstat"
DBAR_TIMEOUT="$fixture/bin/timeout"
export DBAR_SYS_ROOT DBAR_PROC_ROOT DBAR_AMIXER DBAR_DF DBAR_LPSTAT DBAR_TIMEOUT

mkdir -p "$DBAR_SYS_ROOT/block" "$DBAR_SYS_ROOT/class/net"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply"
mkdir -p "$DBAR_SYS_ROOT/class/thermal" "$DBAR_SYS_ROOT/class/hwmon"
mkdir -p "$DBAR_SYS_ROOT/class/bluetooth" "$DBAR_SYS_ROOT/class/backlight"
mkdir -p "$DBAR_PROC_ROOT/net"
printf '%s\n' 'Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT' \
    > "$DBAR_PROC_ROOT/net/route"

cat > "$DBAR_TIMEOUT" <<'MOCK'
#!/bin/sh
[ "$1" = 2 ] || exit 1
shift
exec "$@"
MOCK
cat > "$DBAR_LPSTAT" <<'MOCK'
#!/bin/sh
case "$1" in
    -p)
        case "${DBAR_TEST_CUPS:-idle}" in
            idle|jobs3|queue-error)
                printf 'printer Office is idle.\nprinter Photo is idle.\n' ;;
            missing) printf 'lpstat: No destinations added.\n' ;;
            unavailable) exit 1 ;;
            *) exit 1 ;;
        esac
        ;;
    -W)
        [ "$2" = not-completed ] && [ "$3" = -o ] || exit 1
        case "${DBAR_TEST_CUPS:-idle}" in
            jobs3)
                printf 'Office-1 user 123\nOffice-2 user 456\nPhoto-3 user 789\n' ;;
            idle) : ;;
            queue-error) exit 1 ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$DBAR_TIMEOUT" "$DBAR_LPSTAT"

. "$DBAR_HOME/config.sh"
. "$DBAR_HOME/modules/usb.sh"
. "$DBAR_HOME/modules/printers.sh"

update_usb
[ "$USB_COUNT" -eq 0 ] ||
    { echo 'Error: USB count should begin at zero.' >&2; exit 1; }

# Internal disk and empty USB card reader are not counted.
internal="$DBAR_SYS_ROOT/devices/pci0000:00/block/nvme0n1"
reader="$DBAR_SYS_ROOT/devices/pci0000:00/usb1/1-1/block/sda"
mkdir -p "$internal" "$reader"
printf '20000\n' > "$internal/size"
printf '0\n' > "$reader/size"
ln -s "$internal" "$DBAR_SYS_ROOT/block/nvme0n1"
ln -s "$reader" "$DBAR_SYS_ROOT/block/sda"
update_usb
[ "$USB_COUNT" -eq 0 ] ||
    { echo 'Error: Internal disk or empty reader counted as USB storage.' >&2; exit 1; }

# A partition on one USB disk does not add an extra device.
first="$DBAR_SYS_ROOT/devices/pci0000:00/usb1/1-2/block/sdb"
mkdir -p "$first/sdb1"
printf '10000\n' > "$first/size"
printf '6000\n' > "$first/sdb1/size"
printf '1\n' > "$first/sdb1/partition"
ln -s "$first" "$DBAR_SYS_ROOT/block/sdb"
ln -s "$first/sdb1" "$DBAR_SYS_ROOT/block/sdb1"
update_usb
[ "$USB_COUNT" -eq 1 ] ||
    { echo 'Error: One USB disk must count once even with partitions.' >&2; exit 1; }

second="$DBAR_SYS_ROOT/devices/pci0000:00/usb2/2-1/block/sdc"
mkdir -p "$second/device"
printf '30000\n' > "$second/size"
printf '0\n' > "$second/device/type"
ln -s "$second" "$DBAR_SYS_ROOT/block/sdc"
update_usb
[ "$USB_COUNT" -eq 2 ] ||
    { echo 'Error: Two USB storage devices were not detected.' >&2; exit 1; }

# Optical drives are not counted even when on USB.
optical="$DBAR_SYS_ROOT/devices/pci0000:00/usb2/2-2/block/sr0"
mkdir -p "$optical/device"
printf '20000\n' > "$optical/size"
printf '5\n' > "$optical/device/type"
ln -s "$optical" "$DBAR_SYS_ROOT/block/sr0"
update_usb
[ "$USB_COUNT" -eq 2 ] ||
    { echo 'Error: USB optical drive was counted as storage disk.' >&2; exit 1; }

# The module resets its count after removal.
rm "$DBAR_SYS_ROOT/block/sdb" "$DBAR_SYS_ROOT/block/sdc"
update_usb
[ "$USB_COUNT" -eq 0 ] ||
    { echo 'Error: Removed USB drives were not forgotten.' >&2; exit 1; }

# CUPS is optional. Count configured printers separately from pending jobs.
DBAR_TEST_CUPS=missing; export DBAR_TEST_CUPS
update_printers
[ "$PRINTER_COUNT" -eq 0 ] && [ "$PRINTER_JOBS" -eq 0 ] ||
    { echo 'Error: Missing printers should not be shown.' >&2; exit 1; }

DBAR_TEST_CUPS=idle; export DBAR_TEST_CUPS
update_printers
[ "$PRINTER_COUNT" -eq 2 ] && [ "$PRINTER_JOBS" -eq 0 ] ||
    { echo 'Error: Idle printers should show only the printer icon.' >&2; exit 1; }

DBAR_TEST_CUPS=jobs3; export DBAR_TEST_CUPS
update_printers
[ "$PRINTER_COUNT" -eq 2 ] && [ "$PRINTER_JOBS" -eq 3 ] ||
    { echo 'Error: Expected three queued printer jobs.' >&2; exit 1; }

DBAR_TEST_CUPS=queue-error; export DBAR_TEST_CUPS
update_printers
[ "$PRINTER_COUNT" -eq 2 ] && [ "$PRINTER_JOBS" -eq 0 ] ||
    { echo 'Error: Failed queue lookup should retain only the printer icon.' >&2; exit 1; }

DBAR_TEST_CUPS=unavailable; export DBAR_TEST_CUPS
update_printers
[ "$PRINTER_COUNT" -eq 0 ] && [ "$PRINTER_JOBS" -eq 0 ] ||
    { echo 'Error: Unavailable CUPS must hide stale printers and jobs.' >&2; exit 1; }

# Verify the exact compact order and counts, including the clock separator.
ln -s "$first" "$DBAR_SYS_ROOT/block/sdb"
ln -s "$second" "$DBAR_SYS_ROOT/block/sdc"
DBAR_TEST_CUPS=jobs3; export DBAR_TEST_CUPS
printf 'off\n' > "$DBAR_HOME/color-mode"
displayed=$(sh "$DBAR_HOME/dbar" preview)
case "$displayed" in
    *"$DBAR_USB_ICON 2$DBAR_SEPARATOR$DBAR_PRINTER_ICON 3$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: USB/printer status order or counts are wrong.' >&2; exit 1 ;;
esac
[ "$(printf '%s\n' "$displayed" | awk -F '[|]' '{print NF}')" -eq 6 ] ||
    { echo 'Error: Unexpected status segment count with USB and printers.' >&2; exit 1; }
if printf '%s' "$displayed" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome preview contains control bytes.' >&2
    exit 1
fi

DBAR_TEST_CUPS=idle; export DBAR_TEST_CUPS
idle=$(sh "$DBAR_HOME/dbar" preview)
case "$idle" in
    *"$DBAR_USB_ICON 2$DBAR_SEPARATOR$DBAR_PRINTER_ICON$DBAR_SEPARATOR$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: Idle printer must have no numeric suffix.' >&2; exit 1 ;;
esac

DBAR_TEST_CUPS=unavailable; export DBAR_TEST_CUPS
rm "$DBAR_SYS_ROOT/block/sdb" "$DBAR_SYS_ROOT/block/sdc"
hidden=$(sh "$DBAR_HOME/dbar" preview)
case "$hidden" in
    *"$DBAR_USB_ICON"*|*"$DBAR_PRINTER_ICON"*)
        echo 'Error: Missing hardware or CUPS left a segment visible.' >&2
        exit 1 ;;
esac
[ "$(printf '%s\n' "$hidden" | awk -F '[|]' '{print NF}')" -eq 4 ] ||
    { echo 'Error: Hidden USB/printer modules left extra separators.' >&2; exit 1; }

printf '%s\n' 'USB and printer module tests passed.'
