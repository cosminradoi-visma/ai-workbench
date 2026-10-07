---
name: kb-link-repo
description: Connects a code repo to its workbench item. Writes AGENTS.md, CLAUDE.md and CLAUDE.local.md from the real build files, adds guards, a reviewer agent and golden tasks. Run it by typing /kb-link-repo.
disable-model-invocation: true
---

# kb-link-repo

You need the repo path and the workbench path. Ask for whichever is missing.

- **No repo they may use** (company rules, nothing cloned yet)? Offer a small public practice repo with a README,
  a build file, CI and tests: `git clone https://github.com/expressjs/cors ~/code/cors`. Linking it needs nothing
  installed; running its tests needs Node.
- **This session must reach the repo.** If it's outside the workbench, the user types `/add-dir <repo path>` first
  (or starts with `claude --add-dir <repo path>`), so you can read and write there without a prompt for every file.

## Steps

1. **Read the repo cheaply:** README, the build or manifest file (`package.json`, `pom.xml`,
   `*.csproj`, `pyproject.toml`, `go.mod`, `Makefile`), CI config, any existing
   `CLAUDE.md` / `AGENTS.md` / `.cursor/rules` / `.github/copilot-instructions.md`.
   Don't read source beyond what you need for commands and the non-obvious conventions.
2. **Work item:** if `2-work/<name>/` doesn't exist, create it from the template (kind `repo`)
   and add it to `2-work/README.md`, `INDEX.md` and `NOW.md`. If `4-know/systems/` has no page for what this
   repo is, offer one from `0-meta/templates/system.md`, filled from the README and CI (owner, depends on, environments).
3. **`AGENTS.md`** from `3-toolbox/project-kit/AGENTS.md`: fill `## Operate` (keep that exact heading, the W3 bot
   reads it) from the build files;
   "proving a change works" from CI; conventions only if non-obvious. **No repo overview.**
   Under 100 lines. If one exists, **merge**: keep everything still true, show the diff, never
   overwrite. If other tools' instruction files exist, fold their content into `AGENTS.md` and
   leave a one-line pointer behind.
4. **`CLAUDE.md`, always:** `@AGENTS.md` plus the compaction line. Then ask: **will an agent run here unattended**
   (a bot, a schedule, CI)?
   - **No:** create `CLAUDE.local.md` from `CLAUDE.local.md.example`: the import of `2-work/<name>/state.md` with the
     real workbench path (replace `~/workbench` if it lives elsewhere). Make sure `CLAUDE.local.md` is in `.gitignore`.
   - **Yes:** **no `CLAUDE.local.md`** (it would feed your private workbench to every run). Add deny rules for the
     private half to the repo's `.claude/settings.json`: `Read(<workbench>/1-me/**)`, `Read(<workbench>/2-work/**)`,
     `Read(<workbench>/4-know/**)`, `Read(<workbench>/NOW.md)`, and the "who may start it, anyone can stop it" lines to `AGENTS.md`.
5. **Guard rails:** merge the kit's `.claude/settings.json` into the repo's (union of the `deny` and `ask` lists, keep
   existing hooks and add the kit's two: the prompt guard and the em-dash line) and copy `rules/tests.md`. No scripts: the guards are settings.
   Add the repo's test command to `permissions.allow` (e.g. `Bash(make test)`), so the reviewer can run it.
6. **Checks (drawer 7):** copy `.claude/agents/reviewer.md`, `.claude/skills/golden-run/` and `.claude/golden/` (README and the two examples as formats:
   `example.md` fails until you replace it).
   Offer to draft **three golden tasks** from recently fixed bugs (`git log --oneline -30`): each a small real job
   with a `check:` command that fails before the fix and passes after, and `protect:` on the tests. If the repo will run
   a bot, add two or three must-decline tasks in the format of `example-must-decline.md`. Don't run
   them without asking; they cost tokens. Make sure the card has a `- Repo: \`<path>\`` line so `kb-score` sees the repo.
7. **MCP (optional):** ask which live systems the work needs. Propose a pinned, read-only `.mcp.json`
   and run `kb-vet` on each server. Skip if none.
8. **Prove it:** ask the user to open a fresh **interactive** `claude` in the repo, approve the one-time prompt for the
   external import (`CLAUDE.local.md` → the workbench), and ask "How do I test this, and what's next?". It should answer
   without exploring. Headless, the external import isn't loaded: add `--add-dir <workbench>` to `claude -p`.
9. **Commit `.claude/` (hooks, settings, agents, golden) before any bot or golden run:** they run in worktrees of
   `HEAD`, so uncommitted guards are simply absent there.
10. Tell the user what to commit (AGENTS.md, CLAUDE.md, .claude/) and what stays local (CLAUDE.local.md).

## Don't

- Commit or push. That's the user's call.
- Put personal paths or KB content in files the team commits.
