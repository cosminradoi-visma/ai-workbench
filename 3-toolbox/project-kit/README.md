# Project kit

Files that connect a code repo to your workbench and add guard rails. `kb-link-repo`
copies them and fills in the blanks from the repo's real build files. It merges and never overwrites.

| File | Goes to | Commit? | Does |
|------|---------|---------|------|
| `AGENTS.md` | repo root | yes | The repo's instructions for every agent: commands, proof, conventions, boundaries |
| `CLAUDE.md` | repo root | yes | Imports `AGENTS.md`; Claude-only notes |
| `CLAUDE.local.md.example` | repo root as `CLAUDE.local.md` | **no**, gitignore it | Your personal link to this item's `state.md` in the workbench |
| `.claude/settings.json` | repo | yes | The guards, with nothing to run: deny rules for secret files, force-push and `--no-verify`; ask before push, installs, `curl` and agent-config edits; a prompt hook (no secrets in prompts) and a one-line em-dash check. See `../hooks.md` |
| `.claude/agents/reviewer.md` | repo | yes | A fresh-eyes, read-only reviewer: "review this" → PASS / CHANGES NEEDED with file:line |
| `.claude/golden/` | repo | yes | Golden tasks: a real job, a check it can't influence, files it may not touch |
| `.claude/skills/golden-run/` | repo | yes | Type `/golden-run`: each task in a clean worktree with a fresh agent, then its check; pass count and cost |
| `.claude/rules/tests.md` | repo | yes | Example path-scoped rule: loads only when test files are read |
| `mcp.json.example` | repo root as `.mcp.json` | yes | Per-repo MCP servers, pinned and read-only first |

Nothing here is a script: every file is markdown or Claude Code settings, so it works the same on
Windows, macOS and Linux with nothing installed. The deny rules are guarantees for what they name; the
prompt hook is a small model's judgement, very likely but not certain; the em-dash check is one line of
`grep` inside `settings.json` (`../hooks.md` says why).
