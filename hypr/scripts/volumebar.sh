#!/usr/bin/env bash
#
# Volume OSD via the Quickshell notification server, using WirePlumber (wpctl).
# Usage: volumebar.sh up | down | mute
#
# Requires: wpctl (wireplumber), libnotify (notify-send), util-linux (flock)

SINK="@DEFAULT_AUDIO_SINK@"
STEP="5%"
MAX="1.0"   # cap at 100%; raise to 1.5 to allow boost

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$RUNTIME_DIR/volumebar.lock"
ID_FILE="$RUNTIME_DIR/volumebar-notif-id"

# Serialize rapid keypresses / held keys so runs can't race each other.
exec 9>"$LOCK_FILE"
flock -w 2 9 || exit 0

case "$1" in
    up)   wpctl set-mute "$SINK" 0; wpctl set-volume -l "$MAX" "$SINK" "${STEP}+" ;;
    down) wpctl set-mute "$SINK" 0; wpctl set-volume "$SINK" "${STEP}-" ;;
    mute) wpctl set-mute "$SINK" toggle ;;
    *)    echo "usage: ${0##*/} up|down|mute" >&2; exit 1 ;;
esac

# wpctl prints e.g. "Volume: 0.45" or "Volume: 0.45 [MUTED]"
out="$(wpctl get-volume "$SINK")"
volume="$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$out")"

if [[ "$out" == *MUTED* ]]; then
    icon="audio-volume-muted"
    body="Muted"
else
    if   [ "$volume" -ge 66 ]; then icon="audio-volume-high"
    elif [ "$volume" -ge 33 ]; then icon="audio-volume-medium"
    else                            icon="audio-volume-low"
    fi
    body="${volume}%"
fi

# Reuse the same notification id so every press updates one card in place.
# -p always captures the id, so if the old card already expired we just adopt the new one.
args=(-a VolumeOSD -p -i "$icon" -t 1500 -h boolean:transient:true -u low)
prev_id=""
[ -f "$ID_FILE" ] && prev_id="$(cat "$ID_FILE" 2>/dev/null)"
[ -n "$prev_id" ] && args+=(-r "$prev_id")

new_id=$(notify-send "${args[@]}" "Volume" "$body" 2>/dev/null)
[ -n "$new_id" ] && echo "$new_id" > "$ID_FILE"
