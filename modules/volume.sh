#!/bin/sh

VOLUME_PERCENT=-1
VOLUME_MUTED=0

# Read playback volume from the first usable ALSA mixer control.
update_volume() {
    VOLUME_PERCENT=-1
    VOLUME_MUTED=0

    volume_amixer=${DBAR_AMIXER:-amixer}
    volume_device=${DBAR_ALSA_DEVICE:-default}
    command -v "$volume_amixer" >/dev/null 2>&1 || return 0

    for volume_control in Master Speaker PCM Headphone; do
        mixer_data=$("$volume_amixer" -D "$volume_device" \
            sget "$volume_control" 2>/dev/null) || continue

        volume_result=$(printf '%s\n' "$mixer_data" | awk '
            /Playback/ {
                value = -1
                state = ""
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^\[[0-9]+%\]$/) {
                        percentage = $i
                        gsub(/[^0-9]/, "", percentage)
                        value = percentage + 0
                    }
                    if ($i == "[on]") state = "on"
                    if ($i == "[off]") state = "off"
                }
                if (value >= 0) {
                    total += value
                    channels++
                    if (state == "on") active++
                    if (state == "off") muted++
                }
            }
            END {
                if (channels > 0)
                    printf "%d %d\n", int(total / channels + 0.5),
                        (muted > 0 && active == 0) ? 1 : 0
            }
        ')

        [ -n "$volume_result" ] || continue
        volume_percentage=${volume_result%% *}
        volume_mute_state=${volume_result##* }
        case "$volume_percentage" in
            ''|*[!0-9]*) continue ;;
        esac
        case "$volume_mute_state" in
            0|1) ;;
            *) continue ;;
        esac
        [ "$volume_percentage" -le 100 ] || continue

        VOLUME_PERCENT=$volume_percentage
        VOLUME_MUTED=$volume_mute_state
        if [ "$VOLUME_PERCENT" -eq 0 ]; then
            VOLUME_MUTED=1
        fi
        return 0
    done
}
