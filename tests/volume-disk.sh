#!/bin/sh
set -eu

# Test ALSA playback, compact mute, disk thresholds, and optional segments.
source_repository=${DBAR_HOME:-"$(CDPATH= cd "$(dirname "$0")/.." && pwd)"}
fixture=$(mktemp -d)
trap 'rm -R "$fixture"' 0
mkdir -p "$fixture/bin"

cat > "$fixture/bin/amixer" <<'MOCK'
#!/bin/sh
[ "$1" = -D ] && [ "$2" = default ] && [ "$3" = sget ] || exit 1
case "${DBAR_TEST_MIXER_MODE:-unavailable}:$4" in
    stereo:Master)
        printf '%s\n' 'Front Left: Playback 32 [32%] [-20.00dB] [on]' \
                      'Front Right: Playback 48 [48%] [-20.00dB] [on]' ;;
    mute:Master)
        printf '%s\n' 'Mono: Playback 75 [75%] [-20.00dB] [off]' ;;
    zero:Master)
        printf '%s\n' 'Mono: Playback 0 [0%] [-65.00dB] [on]' ;;
    pcm:PCM)
        printf '%s\n' 'Front Left: Playback 64 [64%] [-20.00dB]' ;;
    speaker:Speaker)
        printf '%s\n' 'Mono: Playback 29 [29%] [-20.00dB] [on]' ;;
    *) exit 1 ;;
esac
MOCK
cat > "$fixture/bin/df" <<'MOCK'
#!/bin/sh
[ "$1" = -P ] && [ "$2" = / ] || exit 1
case "${DBAR_TEST_DISK_USAGE:-none}" in
    none) exit 1 ;;
    invalid) printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' '/dev/vda 100 100 0 bogus /' ;;
    *) printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' \
        "/dev/vda 100 50 50 ${DBAR_TEST_DISK_USAGE}% /" ;;
esac
MOCK
chmod +x "$fixture/bin/amixer" "$fixture/bin/df"

DBAR_AMIXER="$fixture/bin/amixer"
DBAR_DF="$fixture/bin/df"
DBAR_ALSA_DEVICE=default
export DBAR_AMIXER DBAR_DF DBAR_ALSA_DEVICE

. "$source_repository/config.sh"
. "$source_repository/modules/volume.sh"
. "$source_repository/modules/disk.sh"

DBAR_TEST_MIXER_MODE=stereo; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_PERCENT" -eq 40 ] && [ "$VOLUME_MUTED" -eq 0 ] ||
    { echo 'Error: Stereo playback average is incorrect.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=mute; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_PERCENT" -eq 75 ] && [ "$VOLUME_MUTED" -eq 1 ] ||
    { echo 'Error: ALSA mute was not detected.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=zero; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_MUTED" -eq 1 ] ||
    { echo 'Error: Zero playback volume was not silenced.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=pcm; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_PERCENT" -eq 64 ] && [ "$VOLUME_MUTED" -eq 0 ] ||
    { echo 'Error: ALSA PCM fallback failed.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=speaker; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_PERCENT" -eq 29 ] ||
    { echo 'Error: ALSA Speaker fallback failed.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=unavailable; export DBAR_TEST_MIXER_MODE
update_volume
[ "$VOLUME_PERCENT" -eq -1 ] ||
    { echo 'Error: Unavailable playback control was not hidden.' >&2; exit 1; }

for percent in 62 81 95; do
    DBAR_TEST_DISK_USAGE=$percent; export DBAR_TEST_DISK_USAGE
    update_disk
    [ "$DISK_PERCENT" -eq "$percent" ] ||
        { echo 'Error: Root disk usage was not parsed.' >&2; exit 1; }
done
DBAR_TEST_DISK_USAGE=invalid; export DBAR_TEST_DISK_USAGE
update_disk
[ "$DISK_PERCENT" -eq -1 ] ||
    { echo 'Error: Invalid disk usage was not hidden.' >&2; exit 1; }

# Copy only files used by preview; never include the checkout's .git directory.
DBAR_HOME="$fixture/dbar"
mkdir -p "$DBAR_HOME"
cp -v "$source_repository/dbar" "$DBAR_HOME/dbar" >/dev/null
cp -v "$source_repository/config.sh" "$DBAR_HOME/config.sh" >/dev/null
cp -Rv "$source_repository/modules" "$DBAR_HOME/modules" >/dev/null
cp -Rv "$source_repository/lib" "$DBAR_HOME/lib" >/dev/null
DBAR_PROC_ROOT="$fixture/proc"
DBAR_SYS_ROOT="$fixture/sys"
mkdir -p "$DBAR_PROC_ROOT/net"
mkdir -p "$DBAR_SYS_ROOT/class/net"
mkdir -p "$DBAR_SYS_ROOT/class/power_supply"
export DBAR_HOME DBAR_PROC_ROOT DBAR_SYS_ROOT

DBAR_TEST_MIXER_MODE=stereo
DBAR_TEST_DISK_USAGE=62
export DBAR_TEST_MIXER_MODE DBAR_TEST_DISK_USAGE
printf 'off\n' > "$DBAR_HOME/color-mode"
normal=$(sh "$DBAR_HOME/dbar" preview)
case "$normal" in
    *"$DBAR_VOLUME_ICON 40%$DBAR_SEPARATOR$DBAR_DISK_ICON 62%"*) ;;
    *) echo 'Error: Normal volume and disk segments are missing.' >&2; exit 1 ;;
esac
if printf '%s' "$normal" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo 'Error: Monochrome status contains color codes.' >&2
    exit 1
fi

DBAR_TEST_MIXER_MODE=mute
export DBAR_TEST_MIXER_MODE
muted=$(sh "$DBAR_HOME/dbar" preview)
case "$muted" in
    *"$DBAR_VOLUME_MUTED_ICON$DBAR_SEPARATOR$DBAR_DISK_ICON 62%"*) ;;
    *) echo 'Error: Muted volume must be an icon-only segment.' >&2; exit 1 ;;
esac
case "$muted" in
    *MUTE*) echo 'Error: Mute text must not be displayed.' >&2; exit 1 ;;
esac

DBAR_TEST_MIXER_MODE=unavailable
export DBAR_TEST_MIXER_MODE
missing=$(sh "$DBAR_HOME/dbar" preview)
case "$missing" in
    *"$DBAR_VOLUME_ICON"*|*"$DBAR_VOLUME_MUTED_ICON"*)
        echo 'Error: Volume must disappear without a usable ALSA control.' >&2
        exit 1 ;;
esac
[ "$(printf '%s\n' "$missing" | awk -F '[|]' '{print NF}')" -eq 5 ] ||
    { echo 'Error: Missing volume left an extra separator.' >&2; exit 1; }

DBAR_TEST_MIXER_MODE=mute
export DBAR_TEST_MIXER_MODE
printf 'on\n' > "$DBAR_HOME/color-mode"
orange=$(printf '\004')
red=$(printf '\003')
colored_mute=$(sh "$DBAR_HOME/dbar" preview)
case "$colored_mute" in
    *"$orange$DBAR_VOLUME_MUTED_ICON"*) ;;
    *) echo 'Error: Muted icon should be highlighted orange.' >&2; exit 1 ;;
esac

DBAR_TEST_DISK_USAGE=81
export DBAR_TEST_DISK_USAGE
colored_warning=$(sh "$DBAR_HOME/dbar" preview)
case "$colored_warning" in
    *"$orange$DBAR_DISK_ICON 81%"*) ;;
    *) echo 'Error: Disk warning should be highlighted orange.' >&2; exit 1 ;;
esac

DBAR_TEST_DISK_USAGE=95
export DBAR_TEST_DISK_USAGE
colored_critical=$(sh "$DBAR_HOME/dbar" preview)
case "$colored_critical" in
    *"$red$DBAR_DISK_ICON 95%"*) ;;
    *) echo 'Error: Disk critical usage should be highlighted red.' >&2; exit 1 ;;
esac

DBAR_TEST_DISK_USAGE=none
export DBAR_TEST_DISK_USAGE
no_disk=$(sh "$DBAR_HOME/dbar" preview)
case "$no_disk" in
    *"$DBAR_DISK_ICON"*) echo 'Error: Unavailable disk must be hidden.' >&2; exit 1 ;;
esac

printf '%s\n' 'Volume and disk module tests passed.'
