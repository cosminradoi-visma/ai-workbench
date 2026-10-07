# Project kit

Files that connect a code repo to your workbench and add guard rails. `kb-link-repo`
copies them and fills in the blanks from the repo's real build files. It merges and never overwrites.

| File | Goes to | Commit? | Does |
|------|---------|---------|------|
| `AGENTS.md` | repo root | yes | The repo's instructions for every agent: commands, proof, conventions, boundaries |
| `CLAUDE.md` | repo root | yes | Imports `AGENTS.md`; Claude-only notes |
| `CLAUDE.local.md.example` | repo root as `CLAUDE.local.md` | **no**, gitignore it | Your personal link to this item's `state.md` in the workbench |
| `.claude/settings.json` | repo | yes | Denies secret files, asks before push/publish, wires both guards |
| `.claude/hooks/guard.py` + `guard.pl` | repo | yes | Blocks secrets, force-push naming main/master/prod*/release*, pipe-to-shell, file uploads, destructive SQL; asks on installs and agent-config edits |
| `.claude/hooks/prompt_guard.py` + `.pl` | repo | yes | Stops pasted tokens, keys, real IBANs and Romanian CNPs before they reach the model |
| `.claude/hooks/no_em_dash.py` + `.pl` | repo | yes | House style: an em-dash in new prose goes back to the agent to rewrite (extend `BANNED` with yours) |
| `.claude/hooks/py` | repo | yes | Runs each hook on the first *working* Python 3 (skips the Windows Store and macOS stubs), else its Perl twin |
| `gitattributes` | repo root as `.gitattributes` (merge) | yes | Keeps hooks LF on Windows checkouts, or they silently stop running |
| `.claude/agents/reviewer.md` | repo | yes | A fresh-eyes, read-only reviewer: "review this" → PASS / CHANGES NEEDED with file:line |
| `.claude/golden/` | repo | yes | Golden tasks + `run.sh`: clean worktree per task, headless run, a check it can't influence, pass count and cost |
| `.claude/unattended.json.example` | repo as `.claude/unattended.json` | yes | Bots and scheduled runs only: private paths it may never read, a post budget on send tools |
| `.claude/STOP` (you create it) | repo | no | The stop switch: while it exists, the guard blocks every tool call |
| `.claude/rules/tests.md` | repo | yes | Example path-scoped rule: loads only when test files are read |
| `mcp.json.example` | repo root as `.mcp.json` | yes | Per-repo MCP servers, pinned and read-only first |
| `pre-commit-config.yaml` | repo root as `.pre-commit-config.yaml` | yes | gitleaks secret scan on every commit |

Hooks need `sh` and either Python 3.8+ or Perl. Git brings both `sh` and Perl on Windows (Git Bash, which Claude Code
runs hooks through), macOS and Linux, so there is nothing extra to install. Each `.py` hook has a `.pl` twin with the
same rules and messages; `sh kb test` in the workbench proves they agree. If neither runtime is found, every tool call
shows "Neither Python 3 nor Perl found, so guard.py is NOT running (guards off)". The call still goes through, so the
guards are off but never silently.
