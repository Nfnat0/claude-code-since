# claude-since

Show "idle time since the assistant finished its last response" in the Claude Code statusLine.

```
# while you type / read                  -> counts up
MODEL Opus 4.7 | since 0s
MODEL Opus 4.7 | since 47s
MODEL Opus 4.7 | since 3m12s

# while Claude is generating a response  -> frozen at 0s
MODEL Opus 4.7 | since 0s
```

The counter freezes at `0s` while the assistant is working, then starts counting from `0s` again the moment the response ends. Also resets on session start, resume, `/clear`, and auto-compaction.

## How it works

```
[UserPromptSubmit]                        [Stop / SessionStart]
 (you sent a prompt)                       (response end / new / resume / clear / compact)
        |                                          |
        v                                          v
 hooks/thinking-start.sh             hooks/stop-timestamp.sh
 -> writes "thinking" flag           -> writes epoch to last_stop_*
                                     -> deletes "thinking" flag
        |                                          |
        +---------------+--------------------------+
                        v
        ~/.claude/state/thinking_*       <-- presence = "frozen at 0s"
        ~/.claude/state/last_stop_*      <-- baseline for counter
                        |
                        v   (statusLine refreshInterval)
                lib/since.sh (sourced)
                -> $SINCE         "0s" / "1m05s" / "n/a"
                -> $SINCE_SECONDS  raw seconds
                -> $SINCE_THINKING 1 while frozen, 0 otherwise
```

- **UserPromptSubmit** writes a `thinking_*` flag; statusline shows `0s` while present.
- **Stop** removes the flag and writes a fresh `last_stop_*`; counter starts incrementing from there.
- **SessionStart** does the same as Stop on new / `--resume` / `/clear` / compact.
- A stale `thinking_*` flag is auto-ignored after `CLAUDE_SINCE_THINKING_TTL` seconds (default 1800) so a crashed session does not leave the counter pinned at 0.
- No daemon, no IPC. Hooks fire only on events; statusline reads files only on refresh.

## Requirements

- `bash` 4+ (uses `${EPOCHSECONDS}` if bash 5+, falls back to `date +%s`)
- `jq` (used by hook + installer; the snippet itself works without jq if you skip session-id awareness)
- Claude Code CLI

Linux, macOS, WSL all supported. No daemon — runs only when Claude Code calls the hook or refreshes statusLine.

## Install

```bash
git clone https://github.com/Nfnat0/claude-code-since.git ~/claude-code-since
~/claude-code-since/install.sh
```

What `install.sh` does:

1. Backs up `~/.claude/settings.json` to `settings.json.bak.<timestamp>`.
2. Adds hook entries (idempotent):
   - `Stop`, `SessionStart` -> `hooks/stop-timestamp.sh`
   - `UserPromptSubmit` -> `hooks/thinking-start.sh`
3. Sets `statusLine.refreshInterval = 5` (skip with `--keep-interval`).

Options:

```
install.sh                # default install
install.sh --keep-interval   # do not touch refreshInterval
install.sh --dry-run         # print resulting JSON, no write
install.sh --settings PATH   # target a different settings file
```

## Use $SINCE in your existing statusline

If you already have a custom statusLine script, just source the snippet:

```bash
#!/usr/bin/env bash
input="$(cat)"

. /path/to/claude-since/lib/since.sh

# now $SINCE and $SINCE_SECONDS are defined
echo "since $SINCE"
```

`$SINCE_SECONDS` is the raw integer, useful for thresholds:

```bash
if [ -n "$SINCE_SECONDS" ] && [ "$SINCE_SECONDS" -gt 300 ]; then
  echo "idle >5m"
fi
```

## Use the bundled minimal statusline

If you don't have a statusline yet, point Claude Code at the bundled example:

```json
"statusLine": {
  "type": "command",
  "command": "/abs/path/to/claude-since/examples/statusline-minimal.sh",
  "padding": 1,
  "refreshInterval": 5
}
```

Output: `MODEL <name> | since <elapsed>`.

## Configuration

| Env var                       | Default                    | Description                                              |
|-------------------------------|----------------------------|----------------------------------------------------------|
| `CLAUDE_SINCE_STATE_DIR`      | `~/.claude/state`          | Where timestamp / thinking files are kept                |
| `CLAUDE_SINCE_THINKING_TTL`   | `1800`                     | Seconds; ignore stale "thinking" flag older than this    |
| `CLAUDE_SETTINGS`             | `~/.claude/settings.json`  | Used by install/uninstall                                |

## Uninstall

```bash
~/claude-code-since/uninstall.sh              # remove hook entries only
~/claude-code-since/uninstall.sh --purge-state  # also delete state files
```

The package is self-contained — once uninstalled you can delete the directory.

## Files

```
claude-since/
├── README.md
├── LICENSE                       MIT
├── VERSION
├── install.sh                    register hooks + tune statusLine
├── uninstall.sh                  reverse install
├── hooks/
│   ├── stop-timestamp.sh         Stop + SessionStart writer (clears flag)
│   └── thinking-start.sh         UserPromptSubmit writer (sets flag)
├── lib/
│   └── since.sh                  source-able snippet ($SINCE / $SINCE_SECONDS / $SINCE_THINKING)
└── examples/
    └── statusline-minimal.sh     drop-in standalone statusLine
```

## Notes

- `refreshInterval` controls display granularity. With `5`, expect up to 5s lag in the displayed elapsed time.
- Multiple parallel Claude Code sessions all write to the same `last_stop_global`. The statusline reads `last_stop_<session_id>` first when available, so each session shows its own elapsed.
- WSL2 users: `jq` over a pipe can take ~300-500ms per call. The bundled hook + snippet do at most one `jq` invocation each.

## License

MIT.
