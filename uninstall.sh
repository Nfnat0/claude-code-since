#!/usr/bin/env bash
# claude-since uninstaller. Removes the hook entries this package registered.
# Does NOT remove state files in ~/.claude/state — pass --purge-state for that.

set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$PKG_DIR/hooks/stop-timestamp.sh"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
PURGE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --purge-state) PURGE=1 ;;
    --settings)    shift; SETTINGS="$1" ;;
    -h|--help)
      sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2; exit 1
fi

if [ -f "$SETTINGS" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "${SETTINGS}.bak.${ts}"
  echo "backup: ${SETTINGS}.bak.${ts}"

  jq --arg cmd "$HOOK_PATH" '
    def strip($event):
      if .hooks[$event]? then
        .hooks[$event] |= map(
          .hooks |= map(select(.command != $cmd))
        )
        | .hooks[$event] |= map(select((.hooks // []) | length > 0))
        | (if (.hooks[$event] | length) == 0 then del(.hooks[$event]) else . end)
      else . end;

    strip("Stop") | strip("SessionStart")
  ' "$SETTINGS" > "${SETTINGS}.tmp"
  mv "${SETTINGS}.tmp" "$SETTINGS"
  echo "updated: $SETTINGS"
fi

if [ "$PURGE" = 1 ]; then
  state_dir="${CLAUDE_SINCE_STATE_DIR:-$HOME/.claude/state}"
  rm -f "$state_dir"/last_stop_*
  echo "purged: $state_dir/last_stop_*"
fi

echo "claude-since uninstalled."
