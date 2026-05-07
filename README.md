# claude-since

Show "elapsed time since the assistant's last response" in the Claude Code statusLine.

```
MODEL Opus 4.7 | since 0s
MODEL Opus 4.7 | since 47s
MODEL Opus 4.7 | since 3m12s
```

Resets to `0s` automatically when the session is started, resumed, cleared, or compacted.

## How it works

```
[Stop event]            [SessionStart event]
 (response end)          (new / resume / clear / compact)
       \                 /
        \               /
         v             v
     hooks/stop-timestamp.sh
     -> writes epoch to state file
                |
                v
   ~/.claude/state/last_stop_global
   ~/.claude/state/last_stop_<session_id>
                |
                v   (statusLine refreshInterval)
        lib/since.sh (sourced)
        -> $SINCE         "0s" / "1m05s" / "n/a"
        -> $SINCE_SECONDS  raw seconds
```

- Stop hook fires at the end of every assistant response and overwrites the timestamp.
- SessionStart hook fires on new sessions, `--resume`, `/clear`, and auto-compaction. It writes "now", so `$SINCE` starts from `0s`.
- Statusline reads the file each refresh and computes `now - last_stop`. No daemon, no IPC.

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
2. Adds `Stop` and `SessionStart` hook entries pointing at `hooks/stop-timestamp.sh` (idempotent).
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

| Env var                   | Default              | Description                    |
|---------------------------|----------------------|--------------------------------|
| `CLAUDE_SINCE_STATE_DIR`  | `~/.claude/state`    | Where timestamp files are kept |
| `CLAUDE_SETTINGS`         | `~/.claude/settings.json` | Used by install/uninstall |

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
│   └── stop-timestamp.sh         Stop + SessionStart hook
├── lib/
│   └── since.sh                  source-able snippet ($SINCE / $SINCE_SECONDS)
└── examples/
    └── statusline-minimal.sh     drop-in standalone statusLine
```

## Notes

- `refreshInterval` controls display granularity. With `5`, expect up to 5s lag in the displayed elapsed time.
- Multiple parallel Claude Code sessions all write to the same `last_stop_global`. The statusline reads `last_stop_<session_id>` first when available, so each session shows its own elapsed.
- WSL2 users: `jq` over a pipe can take ~300-500ms per call. The bundled hook + snippet do at most one `jq` invocation each.

## License

MIT.
