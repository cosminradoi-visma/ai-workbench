---
updated: 2026-10-07
---

# Hooks and guards, with nothing to run

This workbench ships **no scripts**. Every guard is a setting Claude Code itself enforces, so
there is nothing to install, nothing to keep working on Windows, and nothing to review as code.
`/permissions` and `/hooks` show what is active.

## Two kinds of guard

| Kind | How it decides | Strength | Use it for |
|------|----------------|----------|------------|
| **Permission rules** (`permissions.deny` / `ask` in `.claude/settings.json`) | Claude Code matches the tool call against a pattern | A guarantee for what the pattern names | Secret files, force-push, `--no-verify`, installs, pushes, edits to agent config |
| **Prompt hooks** (`"type": "prompt"`) | A small, fast model reads the event against a rule you wrote in plain words | Very likely, not certain: it is a model's judgement. Each one costs a second and a fraction of a cent | What a pattern can't express: "a real-looking token in this prompt", "an em-dash in new prose" |

Tested on Claude Code 2.1.292 (7 Oct 2026): `cat .env` denied by a `Read(**/.env)` rule, also through
Bash; `git push --force` denied even when the user "authorised" it; a fake `ghp_` token stopped before
the model saw it, while a prompt that only *mentions* `.env` went through; an em-dash in `README.md` blocked.

## What the kit has

All in `project-kit/.claude/settings.json` (this workbench's own `.claude/settings.json` has the same hooks):

| Guard | Kind | Rule |
|-------|------|------|
| No secret files | deny | `Read(**/.env)`, `.env.local`, `*.pem`, `*.key`, `id_rsa*`, `~/.ssh/**`, `~/.aws/**`, … |
| No history rewrites, no skipped hooks | deny | `Bash(git push --force *)`, `Bash(git push -f *)`, `Bash(git commit * --no-verify*)` |
| No `rm -rf` on `/` or `~` | deny | `Bash(rm -rf /*)`, `Bash(rm -rf ~*)` |
| Ask first | ask | `git push`, installs (`npm install`, `pip install`, `dotnet add`), `sudo`, `curl`, `wget`, publish |
| Agent config changes ask | ask | `Edit(./.claude/**)`, `Edit(./AGENTS.md)`, `Edit(./CLAUDE.md)`, `Edit(./.mcp.json)`, `Edit(./.github/workflows/**)` |
| No secrets in prompts | prompt hook, `UserPromptSubmit` | real-looking tokens, keys, passwords in connection strings, IBANs, national IDs; `synthetic:` passes |
| House style | prompt hook, `PreToolUse` on Write/Edit | no em-dashes in new prose (`.md`, `.txt`, `.html`). The write is blocked and the reason shown; say "rewrite it" |

## The shape of a prompt hook

```json
{ "hooks": { "PreToolUse": [ { "matcher": "Write|Edit|MultiEdit", "hooks": [ { "type": "prompt", "timeout": 20,
  "prompt": "House style: no em-dashes in prose. Hook input: $ARGUMENTS ... Reply with JSON only: {\"ok\": true} or {\"ok\": false, \"reason\": \"...\"}" } ] } ] } }
```

`$ARGUMENTS` is the event as JSON. Start the prompt with a short, human line: when it blocks, that
line is what you see. Keep the rule narrow and say what passes, or it will block too much.

## Limits, said plainly

- A deny rule matches what it names. `git -C . push --force` is a different command; the sandbox
  (`personal-kit/settings.strict.json`) is the wall for Bash.
- A prompt hook can be wrong both ways. It is a speed bump with good judgement, not a lock.
- Command hooks (`"type": "command"`) run a script. They are powerful, and they are code you must review
  and keep working on every laptop. This workbench ships none; if your team adds one, treat it like code.
