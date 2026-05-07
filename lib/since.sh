#!/usr/bin/env bash
# claude-since: source-able snippet for any statusLine script.
#
# Required input:
#   $input    JSON read from stdin by the host script (i.e. input="$(cat)")
# Optional env:
#   CLAUDE_SINCE_STATE_DIR   override state dir (default ~/.claude/state)
#
# Exposed variables (after sourcing):
#   $SINCE           formatted "0s" / "59s" / "1m05s" / "62m05s" / "n/a"
#   $SINCE_SECONDS   raw seconds (empty if unknown)
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

# --- read session_id (optional) ---
__cs_session_id=""
if command -v jq >/dev/null 2>&1 && [ -n "${input:-}" ]; then
  __cs_session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

__cs_state_dir="${CLAUDE_SINCE_STATE_DIR:-$HOME/.claude/state}"

# --- pick newest available stop file ---
__cs_stop_file=""
if [ -n "$__cs_session_id" ] && [ -f "$__cs_state_dir/last_stop_${__cs_session_id}" ]; then
  __cs_stop_file="$__cs_state_dir/last_stop_${__cs_session_id}"
elif [ -f "$__cs_state_dir/last_stop_global" ]; then
  __cs_stop_file="$__cs_state_dir/last_stop_global"
fi

SINCE="n/a"
SINCE_SECONDS=""
if [ -n "$__cs_stop_file" ]; then
  __cs_last="$(cat "$__cs_stop_file" 2>/dev/null || echo "")"
  __cs_now="${EPOCHSECONDS:-$(date +%s)}"
  if [ -n "$__cs_last" ] && [ "$__cs_last" -gt 0 ] 2>/dev/null; then
    SINCE_SECONDS=$((__cs_now - __cs_last))
    [ "$SINCE_SECONDS" -lt 0 ] && SINCE_SECONDS=0
    SINCE="$(claude_since__format "$SINCE_SECONDS")"
  fi
fi

unset __cs_session_id __cs_state_dir __cs_stop_file __cs_last __cs_now
