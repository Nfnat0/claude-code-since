#!/usr/bin/env bash
# Minimal Claude Code statusLine using claude-since.
# Shows: model name + elapsed since last response.
#
# Register with:
#   "statusLine": {
#     "type": "command",
#     "command": "/abs/path/to/claude-since/examples/statusline-minimal.sh",
#     "padding": 1,
#     "refreshInterval": 5
#   }

set -u

input="$(cat)"

# Resolve script dir so this works no matter where the package is installed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../lib/since.sh
. "$SCRIPT_DIR/lib/since.sh"

MODEL="Claude"
if command -v jq >/dev/null 2>&1; then
  MODEL="$(printf '%s' "$input" | jq -r '.model.display_name // .model.name // "Claude"' 2>/dev/null || echo Claude)"
fi

printf 'MODEL %s | since %s\n' "$MODEL" "$SINCE"
