---
updated: 2026-10-07
---

# Hooks and guards, with nothing to run

This workbench ships **no scripts**. Every guard is a setting Claude Code itself enforces, so
there is nothing to install, nothing to keep working on Windows, and nothing to review as code.
`/permissions` and `/hooks` show what is active.

## Three kinds of guard

| Kind | How it decides | Strength | Used for |
|------|----------------|----------|----------|
| **Permission rules** (`permissions.deny` / `ask`) | Claude Code matches the tool call against a pattern | A guarantee for what the pattern names | Secret files, force-push, `--no-verify`, installs, pushes, edits to agent config |
| **A prompt hook** (`"type": "prompt"`) | A small, fast model reads the event against a rule in plain words | Very likely, not certain: a model's judgement. About a second per prompt | "A real-looking token in this prompt": no pattern can say that |
| **A one-line check** (`"type": "command"`, written inline in the settings) | `grep` on the event | Exact for what it matches; milliseconds | No em-dashes in prose, through Write, Edit and the shell |

Tested on Claude Code 2.1.292, 7 Oct 2026:

| What we tried | What happened |
|---------------|---------------|
| `cat .env` | denied by a `Read(**/.env)` rule, also through Bash; `grep -r` skipped `.env` too |
| `git push --force` | denied, even when the user "authorised" it |
| a fake `ghp_` token in the prompt | stopped 3 of 3 |
| a harmless question about `.env` files | answered 2 of 2 |
| a token in a prompt starting `synthetic:` | answered |
| an em-dash in `README.md` | kept out 3 of 3, also when the agent tried `printf >> README.md` |

**Why the em-dash check is a line of `grep`, not a prompt hook:** the prompt-hook version let the dash
through in half the runs, and the agent simply wrote the file through the shell instead. A pattern
is exact, so the line catches both. It is the only thing in the workbench that executes, it lives
inside `settings.json` (no file), and it needs `sh` and `grep`: macOS and Linux have them, and on
Windows they come with Git for Windows, which Claude Code uses to run hooks. Without them it
quietly does nothing.

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
| House style | one-line check, `PreToolUse` on Write, Edit, MultiEdit, Bash | an em-dash going into a `.md`, `.txt` or `.html` file is blocked with the reason; the agent explains, and rewrites when you say so |

## The shape of a prompt hook

```json
{ "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "prompt", "timeout": 20,
  "prompt": "Prompt guard: no secrets in prompts. Hook input: $ARGUMENTS ... Reply with JSON only: {\"ok\": true} or {\"ok\": false, \"reason\": \"...\"}" } ] } ] } }
```

`$ARGUMENTS` is the event as JSON. Say exactly what passes and what fails, and fix the reply to one of
two JSON lines: a reply that isn't clean JSON counts as a pass.

## Limits, said plainly

- A deny rule matches what it names. `git -C . push --force` is a different command, and a password in
  `config.py` is not in a secret *file*; the sandbox (`personal-kit/settings.strict.json`) is the wall for Bash.
- A prompt hook can be wrong both ways. It is a speed bump with good judgement, not a lock.
- Told about a block, an agent may offer to get around it. That is why the rules are one layer, and why you read the diff.
