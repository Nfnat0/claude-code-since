#!/usr/bin/env bash
# claude-since: UserPromptSubmit hook.
# Marks the assistant as "working" so the statusline freezes at 0s
# until the matching Stop event fires.
#
# Writes:
#   $CLAUDE_SINCE_STATE_DIR/thinking_global         (always)
#   $CLAUDE_SINCE_STATE_DIR/thinking_<session_id>   (when session_id present)

set -u

input="$(cat 2>/dev/null || true)"
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

state_dir="${CLAUDE_SINCE_STATE_DIR:-$HOME/.claude/state}"
mkdir -p "$state_dir" 2>/dev/null || true

now="${EPOCHSECONDS:-$(date +%s)}"
printf '%s' "$now" > "$state_dir/thinking_global"
if [ -n "$session_id" ]; then
  printf '%s' "$now" > "$state_dir/thinking_${session_id}"
fi

exit 0
