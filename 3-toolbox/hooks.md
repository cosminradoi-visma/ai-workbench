---
updated: 2026-10-02
---

# Hooks

A hook is a command the harness runs at a fixed moment. It runs **outside the model**,
so it always happens and costs no tokens. Reach for one whenever you catch yourself
writing "always" or "never" in a prompt.

Configured in `.claude/settings.json` (repo), `~/.claude/settings.json` (you), or a plugin.
`/hooks` lists what is active.

## The events worth knowing

| Event | When | Can block? | Typical use |
|-------|------|-----------|-------------|
| `SessionStart` | start, resume, after clear/compact | no; stdout goes into context | inject a fact, run a check |
| `UserPromptSubmit` | before your prompt reaches the model | yes | stop pasted secrets or personal data |
| `PreToolUse` | before a tool call | yes; can also `ask` | guard commands and files |
| `PostToolUse` | after a tool call | feedback only | format, lint, scan the diff |
| `Stop` | when the agent wants to finish | yes; keeps it working | "not done until tests pass" |
| `PreCompact` | before compaction | yes | save state first |

Exit code `2` blocks, and stderr goes to the model as the reason. For a softer touch,
print JSON with `"permissionDecision": "ask"` and a reason.

## Recipes

| Recipe | Where |
|--------|-------|
| Guard: block secret files, force-push naming main/master/prod*/release*, pipe-to-shell, file uploads, destructive SQL; ask on installs and agent-config edits | `project-kit/.claude/hooks/guard.py` |
| Prompt guard: stop pasted tokens, private keys, real IBANs and CNPs | `project-kit/.claude/hooks/prompt_guard.py` |
| House style: no em-dashes in prose the agent writes (only its new text, only prose files); it rewrites the line itself | `project-kit/.claude/hooks/no_em_dash.py` |
| Stop switch and unattended fences (private paths, post budget) | `guard.py` + `.claude/STOP` + `.claude/unattended.json` |
| KB health at session start | this KB's `.claude/settings.json` |
| Format on edit | below |
| Not done until tests pass | below |

### Format on edit

```json
{ "hooks": { "PostToolUse": [{ "matcher": "Edit|Write", "hooks": [{ "type": "command",
  "command": "jq -r '.tool_input.file_path' | xargs -r npx prettier --write --ignore-unknown" }] }] } }
```

Swap in `black`, `gofmt -w`, `dotnet format` or whatever the repo uses.

### Not done until tests pass

```json
{ "hooks": { "Stop": [{ "hooks": [{ "type": "command",
  "command": "jq -e '.stop_hook_active' >/dev/null && exit 0; npm test --silent >/dev/null 2>&1 || { echo 'Tests fail. Fix them before finishing.' >&2; exit 2; }" }] }] } }
```

`stop_hook_active` is true when the agent is already continuing because of this hook. Exiting
then prevents an endless loop.

## Rules of thumb

- Fast (well under a second) and quiet. `SessionStart` output costs context, so print problems only.
- Block with a reason the model can act on: "ask the user to run this themselves."
- Hooks run with your permissions on every call. Review them like code, especially in repos you cloned.
