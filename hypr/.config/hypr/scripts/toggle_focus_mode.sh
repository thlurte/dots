#!/usr/bin/env bash
# Focus mode: hide Noctalia top bar + all desktop widgets. Toggle with Super+F.
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia"
STATE_FILE="$STATE_DIR/focus-mode"
IPC=(qs -c noctalia-shell ipc call)

mkdir -p "$STATE_DIR"

is_on() {
  [[ -f "$STATE_FILE" ]] && [[ "$(<"$STATE_FILE")" == "1" ]]
}

if is_on; then
  "${IPC[@]}" bar showBar
  "${IPC[@]}" desktopWidgets enable
  printf '0\n' >"$STATE_FILE"
  command -v notify-send >/dev/null && notify-send -a noctalia -t 1200 "Focus mode" "Off" || true
else
  "${IPC[@]}" bar hideBar
  "${IPC[@]}" desktopWidgets disable
  printf '1\n' >"$STATE_FILE"
  command -v notify-send >/dev/null && notify-send -a noctalia -t 1200 "Focus mode" "On — Super+F to restore" || true
fi
