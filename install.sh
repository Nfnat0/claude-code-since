#!/usr/bin/env bash
# claude-since installer.
#
# What it does:
#   1. Backs up ~/.claude/settings.json -> .bak.<timestamp>
#   2. Adds Stop and SessionStart hooks pointing at this package's
#      hooks/stop-timestamp.sh (idempotent: skips if already registered).
#   3. Optionally lowers statusLine.refreshInterval to 5 (default; --keep-interval to skip).
#   4. Prints integration snippet for your statusline script.
#
# Requires: jq.

set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$PKG_DIR/hooks/stop-timestamp.sh"
THINK_HOOK_PATH="$PKG_DIR/hooks/thinking-start.sh"

SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
SET_INTERVAL=1
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --keep-interval) SET_INTERVAL=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    --settings)      shift; SETTINGS="$1" ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2
  exit 1
fi

chmod +x "$HOOK_PATH" "$THINK_HOOK_PATH" 2>/dev/null || true
chmod +x "$PKG_DIR/lib/since.sh" 2>/dev/null || true
chmod +x "$PKG_DIR/examples/statusline-minimal.sh" 2>/dev/null || true

mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

ts="$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "${SETTINGS}.bak.${ts}"
echo "backup: ${SETTINGS}.bak.${ts}"

JQ_FILTER='
  def ensure_hook($event; $cmd):
    .hooks //= {}
    | (.hooks[$event] //= [])
    | if any(.hooks[$event][]; .hooks // [] | any(.command == $cmd)) then
        .
      else
        .hooks[$event] += [{
          "matcher": "",
          "hooks": [{ "type": "command", "command": $cmd }]
        }]
      end;

  ensure_hook("Stop";              $cmd)
  | ensure_hook("SessionStart";      $cmd)
  | ensure_hook("UserPromptSubmit";  $think_cmd)
  | if $set_interval == "1" then
      (if (.statusLine | type) != "object" then .statusLine = {} else . end)
      | (if (.statusLine.refreshInterval | type) != "number" then .statusLine.refreshInterval = 5 else . end)
      | (if .statusLine.refreshInterval > 5 then .statusLine.refreshInterval = 5 else . end)
    else . end
'

NEW_JSON="$(jq --arg cmd "$HOOK_PATH" --arg think_cmd "$THINK_HOOK_PATH" --arg set_interval "$SET_INTERVAL" "$JQ_FILTER" "$SETTINGS")"

if [ "$DRY_RUN" = 1 ]; then
  echo "--- would write ($SETTINGS) ---"
  echo "$NEW_JSON"
  exit 0
fi

printf '%s\n' "$NEW_JSON" > "$SETTINGS"
echo "updated: $SETTINGS"

cat <<EOF

claude-since installed.

Hooks registered:
  Stop, SessionStart    -> $HOOK_PATH
  UserPromptSubmit      -> $THINK_HOOK_PATH

To use \$SINCE in your own statusline script, source the snippet:

  #!/usr/bin/env bash
  input="\$(cat)"
  . "$PKG_DIR/lib/since.sh"
  printf 'since %s\n' "\$SINCE"

Or use the bundled minimal statusline directly:
  $PKG_DIR/examples/statusline-minimal.sh

Reverse with:
  $PKG_DIR/uninstall.sh
EOF
