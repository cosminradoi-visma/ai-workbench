# w3-reception-kit

An owner-gated reception agent. **Only the owner starts it, anyone can stop it (even mid-run).**
Watch · Decide · Act within fences · Answer. Fixing is one of five routes, not the point.

```
watch.sh    one tick: PAUSED? armed? find approved messages, a worker slot (MAX_WORKERS), atomic claim, work.sh
work.sh     triage (read-only, router schema)  ->  act (that route's tools only; same session, fix_pr a fresh one)
            the script checks the route, runs red-on-base / green-on-head, caps the diff, signs, guards, delivers
install.sh  denies into the repo, bot-settings.json, canary self-test, arms
cleanup.sh  after the lab: worktrees, agent/* branches, claims, outbox, memory, the bot's transcripts
hooks/      stop-guard (every tool, PAUSED / .claude/STOP) · watch-guard (exact search only)
            · witness (raw Slack responses) · slack-guard (where, what, who, 🔕)
```

Routes: **answer = cite · investigate = no edits · fix = red first · decline = template · escalate = owner only.**

## 0. The workshop setup: your DM with yourself

`./find-self-dm.sh` sends you one Slack message and fills `owner.env`: `OWNER_ID`, `CHANNEL_ID` (your self-DM),
`SELF_DM=true`, the private search tool, and `MCP_DENY` (your other connectors, removed from the bot's runs).
In self-DM mode the trigger adds `from:<@you>`, and a hit counts only if Slack shows you are the DM's only participant.

That makes the untrusted-content leg **smaller, not gone**: forwards, unfurls, pasted text, web results and apps
posting as you still bring other people's words. The drawers are allowed because the way out is closed: posts only
to the claimed thread, no web tools in a session that has seen the drawers, the fix route in a fresh session, and
the model cannot read `WORKBENCH_DIR` (`bot-settings.json`, proven by `install.sh`). The **script** reads `NOW.md`,
`1-me/profile.md`, `how-i-work.md`, `glossary.md` and `2-work/$WORK_ITEM/state.md` and hands them in, size-capped,
in self-DM and in the inbox lane (`USE_WORKBENCH=true`, the default). Team-channel mode (`SOURCE=slack`,
`SELF_DM=false`) never gets them, and is not part of the lab. Never paste customer data, payroll or personal data.

## 1. Install (once per target repo)

```sh
cp owner.env.example owner.env      # set OWNER_ID, TARGET_REPO, SOURCE (setup.sh does this, and your name)
./install.sh                        # writes the denies and bot-settings.json, runs the self-test, arms the watcher
```

`install.sh` merges these denies into `<TARGET_REPO>/.claude/settings.json`: `Read(.env*)`, `Read(**/.env*)`,
`Read(**/*secret*)`, `Edit(.claude/**)`, `Write(.claude/**)`, `Bash(git push * main)`, `Bash(gh pr merge *)`,
`Bash(rm -rf *)`. Then it writes **`bot-settings.json`** (in the reception folder, real absolute paths). Every bot
`claude -p` run (watch, triage, act, post, react, the self-test) gets `--setting-sources project --settings bot-settings.json`,
so your personal allow rules and hooks never apply, and:

- `permissions.blockReadsOutsideWorkingDirectories: true`;
- denies: `Read(//<WORKBENCH_DIR>/**)`, `Read(~/.claude/**)`, `~/.ssh`, `~/.aws`, `~/.azure`, `~/.kube`, `~/.config`,
  `Read(//<owner.env>)`, `Bash(git * --output*)`, `Bash(git *--output=*)`, plus the repo's own denies (its allow rules are not copied);
- `hooks.PreToolUse` with matcher `.*`: `hooks/stop-guard.sh <RECEPTION_DIR>/PAUSED <TARGET_REPO>/.claude/STOP`;
- an opportunistic sandbox: `sandbox.enabled: true, failIfUnavailable: false, allowUnsandboxedCommands: false,
  autoAllowBashIfSandboxed: false, network.allowedDomains: []`, with the repo's `.venv` and uv's Python and cache
  re-opened for reading. macOS, or Linux/WSL2 with bubblewrap **and** socat; elsewhere commands run unsandboxed.

Then one headless Haiku run, with exactly those settings, is told to make each forbidden call: Read and `cat` of two
canaries in the repo (`.env.w3canary`, `w3canary-secret.txt`), Read and `cat` of a canary in `WORKBENCH_DIR`, and
`git log -1 --output=w3canary-output.txt`. Only if every call was attempted and denied, no value leaked and the
output file does not exist, it writes `state/armed`. `watch.sh` refuses to tick without it, and again whenever the
repo settings or `bot-settings.json` change. Not while `PAUSED` or `.claude/STOP` exists (the self-test would prove nothing).

## 2. Run once

File-inbox lane (no Slack needed, works for Codex/Copilot pairs too):

```sh
cp ../weather-api/bugs/03-bergen-sunny-in-rain.md inbox/
./watch.sh --wait                   # claims it and works it in the foreground
cat outbox/03-bergen-sunny-in-rain.md outbox/03-bergen-sunny-in-rain.pr.md
```

A message file may start with front matter: `reacted_by: <id>` (someone else's approval is ignored) and
`edited: true` (declined by the script: changed after approval). Stop one thread: `touch inbox/<id>.no_bell`.

Slack lane: `SOURCE=slack` in `owner.env`. Each tick runs one Haiku search,
`in:<#channel> [from:<@you>] hasmy::robot_face: after:<yesterday>`, which only matches messages **you** reacted to,
checked by Slack with your token. A hit counts only if its `ts` is in Slack's raw response. The edited-after-approval
check is **prompt-only** in this lane (triage is told to decline an edited task; no code checks it).

## 3. What each run may do

| Run | Session | Tools | Never |
|---|---|---|---|
| triage | new (or the thread's) | Read, Grep, Glob, `git log/show/diff/blame/status`, `ls`, `date`; Slack read in the MCP lane; WebSearch only without drawers | tests, scripts, edits, `--output`, absolute paths, `~`, `..`, WebFetch |
| answer | resumes triage | as triage | as triage |
| investigate | resumes triage | + the repo's tests (`$TEST_ALL_CMD`, `$TEST_CMD tests/...`), `scripts/status.sh`, `scripts/smoke.sh` | edits, pytest flags that write or load (`--junitxml`, `-o`, `-p`, `--basetemp`, ...), web with drawers |
| fix_pr | **fresh**: the task, the route, triage's `task_summary` | + Edit, Write, `git bisect run $TEST_CMD tests/...` | web, Slack, `git commit/push`, `gh`, `--output` |
| decline, escalate | resumes triage | Read, Grep, Glob | |
| post, react | none (`--no-session-persistence`) | the one Slack tool, through slack-guard | anything else |

The fix route executes code (the tests it writes). Where the sandbox runs, it is the real boundary; elsewhere it is
the tool lists above. `git push` of `agent/<id>` and `gh pr create` happen only with `ALLOW_PUSH=true`.

## 4. Money

Every run gets `--max-budget-usd` = what is left of `WORK_BUDGET_USD` (this message: triage, act, retries, posts and
reactions) and of `THREAD_BUDGET_USD` (the whole thread), whichever is smaller. A resumed session reports its whole
total, so the script charges per-run deltas (`state/sessions/<sid>.cost`) and keeps the thread's running total in
`state/threads/<ts>/spent`. A thread over its cap gets one short note and no more model runs. `MAX_WORKERS`
(default 2) caps the workers running at once (`state/workers/<n>`); the rest waits for the next tick.

## 5. Run on cron

```cron
*/1 9-18 * * 1-5  cd /path/to/w3-reception-kit && ./watch.sh >>log/cron.log 2>&1
```

No `sh`? Use the skill in a Haiku session: `claude --model haiku --plugin-dir /path/to/w3-reception-kit`, then
`/loop 1m /w3-reception-kit:watch`.

## 6. Stop, and clean up

- Everything: `touch PAUSED` (in the reception folder) or `touch <repo>/.claude/STOP`. The STOP hook blocks the next
  tool call of every running worker, and no new tick starts.
- One thread: 🔕 on the message (Slack) or `touch inbox/<id>.no_bell` (inbox).
- After the lab: `./cleanup.sh` (asks first; `--yes`, `--days N`). Keeps `owner.env`, `bot-settings.json`, `state/armed`.

## Files you will look at

`log/reception.log` (what happened) · `log/runs.jsonl` (route, cost per message and per thread, minutes, fix
session) · `log/denies.log` (every fence that fired) · `outbox/<id>.md` (signed reply) · `outbox/<id>.pr.md` (PR body
with `claude --resume <fix session>`) · `state/claims/<id>/` (triage.json, act.json, route.json, gate.txt).

## Hooks fail closed

Every deny is `echo reason >&2; exit 2`, which Claude Code treats as a block whatever the hook prints. Hooks that
need `jq` (watch-guard, slack-guard, witness) exit 2 without it. `stop-guard.sh` needs neither `jq` nor `owner.env`.
`hooks.json` quotes `"${CLAUDE_PLUGIN_ROOT}"`, so a kit path with spaces works.

## Tests

`tests/run.sh`: offline, no model, no Slack. Every hook fed fake stdin JSON (allow and deny, exit codes, no `jq`),
the STOP hook from a worktree, the inbox watcher (arming, claims, idempotency, PAUSED, owner-only, worker slots,
concurrent ticks), `work.sh` against a fake `claude` (routes, read-only tool lists, drawers per lane and no web with
them, the fresh fix session, cost deltas and caps, the red/green gate, diff cap, guard on the outbox, 🔕, memory),
`install.sh` (bot-settings.json, every canary), CRLF owner.env, `cleanup.sh`.

`tests/slack-lane/run.sh`: the Slack lane end to end against a **fake** Slack MCP server
(`tests/slack-lane/fake_slack.py`, stdio, registered as `claude_ai_Slack` so the real hook matcher applies).
Real `claude -p` runs on Haiku, about $0.25. It proves the kit's side (exact search, witness, owner-only hasmy,
claims, post run, live slack-guard). It cannot prove the real connector's names, payloads or org policy.

## Untested `[T]`

The OS sandbox on a machine that has it; the `edited` field in the connector's output; someone else's reaction
(needs a second account); org send policy. Marked `# [T]` in the code.
