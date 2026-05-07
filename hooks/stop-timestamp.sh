#!/usr/bin/env bash
# claude-since: Stop / SessionStart hook.
# - Stop fires after assistant finishes a response.
# - SessionStart fires on new / --resume / /clear / compact.
# Both write current epoch and clear the "thinking" flag so the
# statusline starts counting from 0s.
#
# Writes:
#   $CLAUDE_SINCE_STATE_DIR/last_stop_global         (always)
#   $CLAUDE_SINCE_STATE_DIR/last_stop_<session_id>   (when session_id present)
# Removes:
#   $CLAUDE_SINCE_STATE_DIR/thinking_global
#   $CLAUDE_SINCE_STATE_DIR/thinking_<session_id>

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
rm -f "$state_dir/thinking_global"
if [ -n "$session_id" ]; then
  printf '%s' "$now" > "$state_dir/last_stop_${session_id}"
  rm -f "$state_dir/thinking_${session_id}"
fi

exit 0
