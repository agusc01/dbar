#!/bin/sh
set -eu

# Test ordering, selective polling, local overrides and validation in isolation.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0

DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME"
cp "$source_repository/dbar" "$DBAR_HOME/dbar"
cp "$source_repository/config.sh" "$DBAR_HOME/config.sh"
cp -R "$source_repository/lib" "$DBAR_HOME/lib"
cp -R "$source_repository/modules" "$DBAR_HOME/modules"
export DBAR_HOME

DBAR_AMIXER=/nonexistent/dbar-amixer
DBAR_DF=/nonexistent/dbar-df
DBAR_LPSTAT=/nonexistent/dbar-lpstat
DBAR_SYS_ROOT="$fixture/sys"
DBAR_PROC_ROOT="$fixture/proc"
mkdir -p "$DBAR_SYS_ROOT/class/net" "$DBAR_SYS_ROOT/block" "$DBAR_PROC_ROOT/net"
printf '%s\n' 'Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT' \
    > "$DBAR_PROC_ROOT/net/route"
export DBAR_AMIXER DBAR_DF DBAR_LPSTAT DBAR_SYS_ROOT DBAR_PROC_ROOT

# Without an override, the existing default order is unchanged.
default_preview=$(sh "$DBAR_HOME/dbar" preview)
. "$DBAR_HOME/config.sh"
case "$default_preview" in
    "$DBAR_CPU_ICON "*"$DBAR_SEPARATOR$DBAR_MEMORY_ICON "*"$DBAR_CLOCK_ICON "*) ;;
    *) echo 'Error: Default module order changed.' >&2; exit 1 ;;
esac

# Local config is loaded after the tracked defaults; no other module is sampled.
cat > "$DBAR_HOME/config.local.sh" <<'LOCAL'
DBAR_MODULES=''
DBAR_MODULES="$DBAR_MODULES clock"
DBAR_MODULES="$DBAR_MODULES network"
DBAR_MODULES="$DBAR_MODULES memory"
LOCAL
printf 'off\n' > "$DBAR_HOME/color-mode"
ordered=$(sh "$DBAR_HOME/dbar" preview)

case "$ordered" in
    "$DBAR_CLOCK_ICON "*"$DBAR_SEPARATOR$DBAR_NETWORK_OFFLINE_ICON$DBAR_SEPARATOR$DBAR_MEMORY_ICON "*) ;;
    *) echo 'Error: Custom module order was not respected.' >&2; exit 1 ;;
esac
[ "$(printf '%s\n' "$ordered" | awk -F '[|]' '{print NF}')" -eq 3 ] ||
    { echo 'Error: Disabled modules left separators.' >&2; exit 1; }
case "$ordered" in
    *"$DBAR_CPU_ICON"*|*"$DBAR_DISK_ICON"*|*"$DBAR_BLUETOOTH_ON_ICON"*)
        echo 'Error: A disabled module is still visible.' >&2; exit 1 ;;
esac

# Preview remains plain text even with a custom module order.
if printf '%s' "$ordered" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome ordered preview contains control bytes.' >&2
    exit 1
fi

# No enabled modules: empty output, and no query should be performed.
printf "DBAR_MODULES=''\n" > "$DBAR_HOME/config.local.sh"
empty=$(sh "$DBAR_HOME/dbar" preview)
[ -z "$empty" ] ||
    { echo 'Error: An empty module list should render an empty status.' >&2; exit 1; }

# Invalid configs must fail before running anything, with explicit diagnostics.
for configured in 'cpu cpu' 'cpu unknown'; do
    printf "DBAR_MODULES='%s'\n" "$configured" > "$DBAR_HOME/config.local.sh"
    if sh "$DBAR_HOME/dbar" preview > "$fixture/output" 2> "$fixture/error"; then
        echo 'Error: Duplicate or unknown module was accepted.' >&2
        exit 1
    fi
    [ -s "$fixture/error" ] ||
        { echo 'Error: Missing invalid-module diagnostic.' >&2; exit 1; }
done

for interval in 0 05 -1 invalid 999999; do
    printf "DBAR_MODULES='clock'\nCLOCK_INTERVAL='%s'\n" "$interval" \
        > "$DBAR_HOME/config.local.sh"
    if sh "$DBAR_HOME/dbar" preview >/dev/null 2>&1; then
        echo "Error: Invalid interval $interval was accepted." >&2
        exit 1
    fi
done

# Non-selected intervals can be invalid without affecting selected modules.
cat > "$DBAR_HOME/config.local.sh" <<'LOCAL'
DBAR_MODULES='clock'
VOLUME_INTERVAL=0
LOCAL
sh "$DBAR_HOME/dbar" preview >/dev/null

# A symlink cannot secretly inject the personal configuration.
rm "$DBAR_HOME/config.local.sh"
ln -s "$DBAR_HOME/config.sh" "$DBAR_HOME/config.local.sh"
if sh "$DBAR_HOME/dbar" preview >/dev/null 2>&1; then
    echo 'Error: A linked personal config was accepted.' >&2
    exit 1
fi
rm "$DBAR_HOME/config.local.sh"

# Verify update dispatch and independent refresh intervals without reading hardware.
. "$DBAR_HOME/lib/modules.sh"
DBAR_MODULES='volume clock'
VOLUME_INTERVAL=2
CLOCK_INTERVAL=3
calls="$fixture/calls"
: > "$calls"
update_volume() { printf 'volume\n' >> "$calls"; }
update_clock() { printf 'clock\n' >> "$calls"; }
update_cpu() { echo 'Error: Disabled CPU module was polled.' >&2; exit 1; }

update_active_modules
[ "$(cat "$calls")" = "$(printf 'volume\nclock')" ] ||
    { echo 'Error: Initial sampling did not follow the active list.' >&2; exit 1; }

: > "$calls"
update_due_modules 1
[ ! -s "$calls" ] ||
    { echo 'Error: A module was sampled before its interval.' >&2; exit 1; }

update_due_modules 2
update_due_modules 3
update_due_modules 6
[ "$(cat "$calls")" = "$(printf 'volume\nclock\nvolume\nclock')" ] ||
    { echo 'Error: Scheduled selective polling is incorrect.' >&2; exit 1; }

printf '%s\n' 'Module ordering and configuration tests passed.'
