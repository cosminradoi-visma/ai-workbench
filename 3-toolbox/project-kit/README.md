# Project kit

Files that connect a code repo to your workbench and add guard rails. `kb-link-repo`
copies them and fills in the blanks from the repo's real build files. It merges and never overwrites.

| File | Goes to | Commit? | Does |
|------|---------|---------|------|
| `AGENTS.md` | repo root | yes | The repo's instructions for every agent: commands, proof, conventions, boundaries |
| `CLAUDE.md` | repo root | yes | Imports `AGENTS.md`; Claude-only notes |
| `CLAUDE.local.md` | repo root | **no**, gitignore it | Your personal link to this item's `state.md` in the workbench |
| `.claude/settings.json` | repo | yes | Denies secret files, asks before push/publish, wires both guards |
| `.claude/hooks/guard.py` | repo | yes | Blocks secrets, force-push, pipe-to-shell, uploads, destructive SQL; asks on installs and agent-config edits |
| `.claude/hooks/prompt_guard.py` | repo | yes | Stops pasted tokens, keys and real IBANs before they reach the model |
| `.claude/hooks/py` | repo | yes | Runs the hooks with the first *working* Python 3 (skips Windows' fake `python3`) |
| `gitattributes` | repo root as `.gitattributes` (merge) | yes | Keeps hooks LF on Windows checkouts, or they silently stop running |
| `.claude/rules/tests.md` | repo | yes | Example path-scoped rule: loads only when test files are read |
| `mcp.json.example` | repo root as `.mcp.json` | yes | Per-repo MCP servers, pinned and read-only first |
| `pre-commit-config.yaml` | repo root as `.pre-commit-config.yaml` | yes | gitleaks secret scan on every commit |

Hooks need Python 3.8+ and `sh`. On Windows, Claude Code runs hooks through Git Bash; install
Python from python.org (not the Store stub). If no Python is found, every tool call shows
"No Python 3 found, so the guard hooks are NOT running". The guards never fail silently.
