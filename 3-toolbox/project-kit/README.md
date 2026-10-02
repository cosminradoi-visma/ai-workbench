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
| `.claude/rules/tests.md` | repo | yes | Example path-scoped rule: loads only when test files are read |
| `mcp.json.example` | repo root as `.mcp.json` | yes | Per-repo MCP servers, pinned and read-only first |
| `pre-commit-config.yaml` | repo root as `.pre-commit-config.yaml` | yes | gitleaks secret scan on every commit |

Hooks need Python 3 (`python3` or `python` on PATH). On Windows, run Claude Code in WSL
or Git Bash. Without Python the guards fail open, meaning they let the call through.
