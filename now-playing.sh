#!/usr/bin/env bash
#
# Now Playing -> deadd-notification-center, updated in place.
# Requires: playerctl, libnotify (notify-send)
# Optional: notify-send.py (pip install --user notify-send.py)

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/now-playing.lock"
REPLACE_TAG="now-playing-panel"

# 1. Single instance: a second copy (e.g. double autostart) would create
#    its own notification id and stack on top of the first.
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# 2. Fresh id for this run. Kept in a variable, not a file, so a stale id
#    from a previous session or a restarted deadd can never be reused.
NOTIF_ID=""

send_notification() {
    local artist="$1" title="$2" status="$3" art="$4"
    local body="${artist:+$artist — }${status}"
    local heading="${title:-Nothing playing}"

    if command -v notify-send.py >/dev/null 2>&1; then
        local args=(--app-name NowPlaying --hint boolean:transient:true)
        [ -n "$art" ] && args+=(--hint "string:image-path:file://${art}")
        notify-send.py "$heading" "$body" "${args[@]}" \
            --replaces-process "$REPLACE_TAG"
        return
    fi

    # Plain notify-send: ALWAYS pass -p so we get the id back, and pass -r
    # once we have one. If deadd dropped the old notification, the server
    # hands back a new id and we simply adopt it.
    local args=(-a NowPlaying -p -h boolean:transient:true)
    [ -n "$art" ] && args+=(-i "$art")
    [ -n "$NOTIF_ID" ] && args+=(-r "$NOTIF_ID")

    local new_id
    new_id=$(notify-send "${args[@]}" "$heading" "$body" 2>/dev/null)
    [ -n "$new_id" ] && NOTIF_ID="$new_id"
}

last_state=""

# Title goes last so a "|" in a song title can't shift the other fields.
playerctl --follow metadata --format \
    '{{status}}|{{artist}}|{{mpris:artUrl}}|{{title}}' 2>/dev/null |
while IFS='|' read -r status artist arturl title; do
    state="${status}|${artist}|${title}"

    # Skip seeks / position pings that aren't a real change.
    [ "$state" == "$last_state" ] && continue
    last_state="$state"

    art=""
    [[ "$arturl" == file://* ]] && art="${arturl#file://}"

    send_notification "$artist" "$title" "$status" "$art"
done
