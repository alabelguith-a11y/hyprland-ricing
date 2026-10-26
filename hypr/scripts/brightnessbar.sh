#!/usr/bin/env bash
#
# Brightness OSD via the Quickshell notification server, using brightnessctl.
# Usage: brightnessbar.sh up | down
#
# Requires: brightnessctl, libnotify (notify-send), util-linux (flock)

STEP="5%"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$RUNTIME_DIR/brightnessbar.lock"
ID_FILE="$RUNTIME_DIR/brightnessbar-notif-id"

# Serialize rapid keypresses / held keys so runs can't race each other.
exec 9>"$LOCK_FILE"
flock -w 2 9 || exit 0

case "$1" in
    up)   brightnessctl -q set "${STEP}+" ;;
    down) brightnessctl -q --min-value=1 set "${STEP}-" ;;   # never goes fully black
    *)    echo "usage: ${0##*/} up|down" >&2; exit 1 ;;
esac

# `brightnessctl -m` prints: device,class,current,percent%,max
pct="$(brightnessctl -m | cut -d, -f4 | tr -d '%')"
[ -n "$pct" ] || exit 0

# Reuse the same notification id so every press updates one card in place.
args=(-a BrightnessOSD -p -i display-brightness -t 1500 -h boolean:transient:true -u low)
prev_id=""
[ -f "$ID_FILE" ] && prev_id="$(cat "$ID_FILE" 2>/dev/null)"
[ -n "$prev_id" ] && args+=(-r "$prev_id")

new_id=$(notify-send "${args[@]}" "Brightness" "${pct}%" 2>/dev/null)
[ -n "$new_id" ] && echo "$new_id" > "$ID_FILE"
