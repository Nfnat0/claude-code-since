#!/usr/bin/env bash
# claude-since: source-able snippet for any statusLine script.
#
# Behavior:
#   - While the assistant is working (UserPromptSubmit fired, no Stop yet):
#       SINCE = "0s", SINCE_SECONDS = 0  (frozen)
#   - After Stop / SessionStart:
#       SINCE = elapsed since that event ("0s" -> "59s" -> "1m05s" ...)
#
# Required input:
#   $input    JSON read from stdin by the host script (i.e. input="$(cat)")
# Optional env:
#   CLAUDE_SINCE_STATE_DIR   override state dir (default ~/.claude/state)
#   CLAUDE_SINCE_THINKING_TTL  seconds; ignore stale thinking flag older
#                              than this value (default 1800)
#
# Exposed variables (after sourcing):
#   $SINCE           formatted "0s" / "59s" / "1m05s" / "62m05s" / "n/a"
#   $SINCE_SECONDS   raw seconds (empty if unknown)
#   $SINCE_THINKING  "1" while frozen during a response, "0" otherwise
#
# Example host usage:
#   #!/usr/bin/env bash
#   input="$(cat)"
#   . /path/to/claude-since/lib/since.sh
#   echo "since ${SINCE}"

# Format seconds: <60 -> "Ns", >=60 -> "NmMMs".
claude_since__format() {
  local s="$1"
  if [ "$s" -lt 60 ]; then
    printf '%ds' "$s"
  else
    printf '%dm%02ds' $((s / 60)) $((s % 60))
  fi
}

__cs_session_id=""
if command -v jq >/dev/null 2>&1 && [ -n "${input:-}" ]; then
  __cs_session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

__cs_state_dir="${CLAUDE_SINCE_STATE_DIR:-$HOME/.claude/state}"
__cs_thinking_ttl="${CLAUDE_SINCE_THINKING_TTL:-1800}"
__cs_now="${EPOCHSECONDS:-$(date +%s)}"

# --- thinking flag (per-session preferred, then global) ---
__cs_think_file=""
if [ -n "$__cs_session_id" ] && [ -f "$__cs_state_dir/thinking_${__cs_session_id}" ]; then
  __cs_think_file="$__cs_state_dir/thinking_${__cs_session_id}"
elif [ -f "$__cs_state_dir/thinking_global" ]; then
  __cs_think_file="$__cs_state_dir/thinking_global"
fi

SINCE_THINKING=0
if [ -n "$__cs_think_file" ]; then
  __cs_think_ts="$(cat "$__cs_think_file" 2>/dev/null || echo 0)"
  if [ "$__cs_think_ts" -gt 0 ] 2>/dev/null; then
    if [ "$((__cs_now - __cs_think_ts))" -lt "$__cs_thinking_ttl" ]; then
      SINCE_THINKING=1
    fi
  fi
fi

# --- last stop timestamp ---
__cs_stop_file=""
if [ -n "$__cs_session_id" ] && [ -f "$__cs_state_dir/last_stop_${__cs_session_id}" ]; then
  __cs_stop_file="$__cs_state_dir/last_stop_${__cs_session_id}"
elif [ -f "$__cs_state_dir/last_stop_global" ]; then
  __cs_stop_file="$__cs_state_dir/last_stop_global"
fi

SINCE="n/a"
SINCE_SECONDS=""
if [ "$SINCE_THINKING" = 1 ]; then
  SINCE="0s"
  SINCE_SECONDS=0
elif [ -n "$__cs_stop_file" ]; then
  __cs_last="$(cat "$__cs_stop_file" 2>/dev/null || echo "")"
  if [ -n "$__cs_last" ] && [ "$__cs_last" -gt 0 ] 2>/dev/null; then
    SINCE_SECONDS=$((__cs_now - __cs_last))
    [ "$SINCE_SECONDS" -lt 0 ] && SINCE_SECONDS=0
    SINCE="$(claude_since__format "$SINCE_SECONDS")"
  fi
fi

unset __cs_session_id __cs_state_dir __cs_thinking_ttl __cs_now \
      __cs_think_file __cs_think_ts __cs_stop_file __cs_last
