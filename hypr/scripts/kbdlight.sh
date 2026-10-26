#!/usr/bin/env bash

#
# Keyboard backlight: cycle Off -> Low -> High, with a dunst popup.
# Usage: kbdlight.sh cycle | up | down
#
# Requires: brightnessctl, libnotify (notify-send), dunst (or any notification daemon)

DEV="$(ls /sys/class/leds 2>/dev/null | grep -m1 'kbd_backlight')"
if [ -z "$DEV" ]; then
    notify-send -a KbdLight -u low -t 2000 "Keyboard light" "No backlight found"
    exit 1
fi

cur="$(brightnessctl -d "$DEV" get)"
max="$(brightnessctl -d "$DEV" max)"

# Levels: 0, low (half, rounded up), high (max). Collapse if the keyboard only has on/off.
low=$(( (max + 1) / 2 ))
if [ "$low" -ge "$max" ]; then levels=(0 "$max"); else levels=(0 "$low" "$max"); fi
n=${#levels[@]}

# Current index = highest level that is <= current brightness
idx=0
for i in "${!levels[@]}"; do
    [ "$cur" -ge "${levels[$i]}" ] && idx=$i
done

case "$1" in
    cycle) idx=$(( (idx + 1) % n )) ;;
    up)    [ "$idx" -lt $((n - 1)) ] && idx=$((idx + 1)) ;;
    down)  [ "$idx" -gt 0 ] && idx=$((idx - 1)) ;;
    *)     echo "usage: ${0##*/} cycle|up|down" >&2; exit 1 ;;
esac

new="${levels[$idx]}"
brightnessctl -q -d "$DEV" set "$new"

# Label + progress bar value
if   [ "$idx" -eq 0 ];          then label="Off"
elif [ "$idx" -eq $((n - 1)) ]; then label=$([ "$n" -eq 2 ] && echo "On" || echo "High")
else                                 label="Low"
fi
pct=$(( new * 100 / max ))

# Reuse one notification id (like volumebar.sh) so every press updates the same popup.
# -p prints the id of the notification; -r replaces the previous one.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
ID_FILE="$RUNTIME_DIR/kbdlight-notif-id"

args=(-a KbdLight -p -u normal -t 1500 -h int:value:"$pct")
prev_id=""
[ -f "$ID_FILE" ] && prev_id="$(cat "$ID_FILE" 2>/dev/null)"
[ -n "$prev_id" ] && args+=(-r "$prev_id")

new_id="$(notify-send "${args[@]}" "Keyboard light" "$label")" \
    || echo "kbdlight: notify-send failed (is a notification daemon running?)" >&2
[ -n "$new_id" ] && echo "$new_id" > "$ID_FILE"
