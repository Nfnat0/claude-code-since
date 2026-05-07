#!/usr/bin/env bash
# claude-since: timestamp writer hook.
# Triggered by both Stop (response end) and SessionStart (new/resume/clear/compact).
#
# Writes epoch seconds to:
#   $CLAUDE_SINCE_STATE_DIR/last_stop_global         (always)
#   $CLAUDE_SINCE_STATE_DIR/last_stop_<session_id>   (when session_id present)
#
# State dir defaults to ~/.claude/state. Override with CLAUDE_SINCE_STATE_DIR.

set -u

input="$(cat 2>/dev/null || true)"
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

state_dir="${CLAUDE_SINCE_STATE_DIR:-$HOME/.claude/state}"
mkdir -p "$state_dir" 2>/dev/null || true

now="${EPOCHSECONDS:-$(date +%s)}"
printf '%s' "$now" > "$state_dir/last_stop_global"
if [ -n "$session_id" ]; then
  printf '%s' "$now" > "$state_dir/last_stop_${session_id}"
fi

exit 0
