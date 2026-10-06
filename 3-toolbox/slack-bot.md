---
updated: 2026-10-06
status: draft
verified: claude.ai Slack connector, Visma workspace, the owner's self-DM (5–6 Oct); the hardening (bot-settings.json, STOP hook, install canaries) on Linux/WSL2, Claude Code 2.1.288 (6 Oct). Untested items are marked [T].
---

# A Slack bot that uses your workbench (W3, part 2)

Part 1 gave your agent its drawers: who you are, what you're on, how your repo works. Part 2 gives it a trigger.
You write to yourself in Slack, react 🤖, and your bot answers in the thread, using those drawers, on the
`weather-api` practice repo or on your own repo.

No Slack app and no bot token to get approved: it runs on your laptop through the **Slack MCP connector**
(`/mcp` shows `claude.ai Slack`), with your own login. Code and the trainer's demo: [`slack-bot/`](slack-bot/).

**Never paste customer data, payroll or personal data into your DM for the bot.** Practise on weather-api's bug
reports, your own code questions and your own notes.

## Set it up (about 15 minutes)

At break 1, check your laptop (changes nothing, about a second):

```sh
cd 3-toolbox/slack-bot
sh setup.sh --check              # ✓/✗ for git, jq, uv, python3, claude >= 2.1.259, logged in, the Slack connector
sh setup.sh --check --live       # the same, plus one real one-turn `claude -p` call on Haiku (a fraction of a cent)
```

It exits non-zero if a required line is ✗. The Slack connector and the OS sandbox are reported but not required
(without Slack you use the inbox lane; without the sandbox the fences below still hold, see "The sandbox").

Then, from your workbench clone:

```sh
cd 3-toolbox/slack-bot
sh setup.sh                      # kit + weather-api (with its git history) into ~/w3, both test suites, your name
sh setup.sh --repo ~/code/mine   # or your own repo: run /kb-link-repo for it first (part 1)
cd ~/w3
./kit/find-self-dm.sh            # sends you ONE message; fills OWNER_ID, CHANNEL_ID, SELF_DM=true, MCP_DENY
./kit/install.sh                 # deny rules + bot-settings.json + a self-test; arms the bot only if every canary is denied
./kit/watch.sh --wait            # one tick
```

Then in Slack, in your DM with yourself: write a question, react 🤖, tick again (or keep it running:
`while :; do ./kit/watch.sh; sleep 60; done`). Within a minute or two: 👀, one signed reply, ✅.

Needs: Claude Code v2.1.259 or later, the Slack connector connected in `/mcp`, `git`, `jq`, and `uv` for weather-api.
`setup.sh` fills `OWNER_NAME` and `SIGNATURE` ("🤖 <name>'s agent:") from `git config user.name`.
Workshop defaults in `kit/owner.env`: `WORK_MODEL=sonnet`, `WORK_BUDGET_USD=1` per message, `THREAD_BUDGET_USD=3`
per thread, `MAX_WORKERS=2`, `ALLOW_PR=false`, `ALLOW_PUSH=false`. Your own repo: set `TEST_CMD` / `TEST_ALL_CMD`
if it doesn't use `uv run pytest`, and give its `AGENTS.md` an `## Operate` section (start, stop, check, test), like weather-api's.
Windows: an `owner.env` saved with CRLF line endings is fine (the scripts strip `\r`), and weather-api ships a
`.gitattributes` that keeps its scripts LF.

## The loop

1. **Watch.** One search per tick: `in:<#your-DM> from:<@you> hasmy::robot_face: after:YYYY-MM-DD`.
   `hasmy::` returns only messages *you* reacted to, so Slack checks it is you. A hook pins the search to exactly
   that query, whatever the model types, and the script reads the hits from Slack's raw response.
2. **Claim.** 👀 on the message. One claim per reacted message, one worker per thread at a time, at most
   `MAX_WORKERS` (2) at once: a burst of 🤖s waits for the next tick.
3. **Decide.** A read-only run reads the **whole thread** (the message you reacted to is the task, everything
   before and after is context) and your drawers. It picks a route. Read-only means: the source, `git log/show/diff/blame`,
   `ls`. No tests, no scripts, no edits, no `git --output`, and no web while your drawers are in the context.
4. **Act.** A second run, same session, gets only that route's tools. Except **fix**: it starts a **fresh session**
   that never saw your drawers, with only the task, the route and a short task summary from triage, and no web tools.
5. **Answer** in the thread, formatted for Slack, signed `🤖 <name>'s agent: <route>`, then ✅.

A 🤖 on a later message in the same thread continues the same session, so the bot remembers what it found.

| Route | When | Rule, checked by the script |
|---|---|---|
| answer | any question or task a reply can complete | claims about the repo cite a file that exists (or a workbench file) |
| investigate | looks like a bug, not proven | no edit tools; may run the repo's tests (pytest flags that write files are denied) |
| fix | a bug it can prove (off unless `ALLOW_PR=true`) | fresh session; the new test fails on the old code and passes on the fix, full suite green, diff ≤ 200 lines / 5 files. Push and `gh pr create` only with `ALLOW_PUSH=true` |
| decline | only when it would leak data | other Slack conversations, files outside the repo, personal files, secrets |
| escalate | security, customer data, production | mentions the owner only, proposes nothing |

Your 🤖 means "do it": it approves the task, never a data leak.

## Why your DM, and how the drawers get in

Rule 5 of [`safety.md`](safety.md): never private data, untrusted content and a way out in one session.
Your drawers are the private data. The bot holds them anyway, so here is the honest version of why that is allowed.

**The self-DM makes the untrusted-content leg smaller, it does not remove it.** Nobody else can post in your DM
with yourself, but other people's words still get in: a message you forward or paste, a link that unfurls, a web
result, an app or integration that posts as you. So the bot treats every message as data, and the exception holds
**only because the way out is closed**:

- posts go only to the claimed thread in that DM, only the text the script approved (a hook checks every Slack call);
- no WebSearch or WebFetch in any run that has the drawers in its context (triage, answer, investigate in that session);
- the fix route, which executes code, starts a fresh session without the drawers;
- the **model cannot read the workbench at all**: the **script** reads `NOW.md`, `1-me/profile.md`, `how-i-work.md`,
  `glossary.md` and, with `WORK_ITEM`, one `2-work/<item>/state.md` (capped at 6 KB each, 20 KB in total) and hands
  them in. `bot-settings.json` denies the model every read of `WORKBENCH_DIR`, and `install.sh` proves it (below).

The drawers go in only in your own lanes: the self-DM (`SELF_DM=true`) and the file inbox (`SOURCE=inbox`).
`USE_WORKBENCH=false` turns them off. **Team-channel mode** (`SOURCE=slack`, `SELF_DM=false`) brings the untrusted
leg back in full, so it never gets the drawers. It is not part of the lab.

## Fences, and where each lives

| Fence | How |
|---|---|
| Only you start it | the pinned `hasmy::` search, plus the participants check in self-DM |
| Anyone can stop it, even mid-run | 🔕 on the thread (checked before every post), `touch kit/PAUSED`, or `touch .claude/STOP` in the repo (the same file `guard.py` uses). A hook on **every tool call** (`hooks/stop-guard.sh`) checks both files, also from inside a worktree, so a run stops at its next step |
| Not your personal setup | every bot `claude -p` run uses `--setting-sources project`: your own allow rules and hooks in `~/.claude` do not apply |
| What it may read | `bot-settings.json` (written by `install.sh`, real paths): `blockReadsOutsideWorkingDirectories`, denies on `WORKBENCH_DIR`, `~/.claude`, `~/.ssh`, `~/.aws`, `~/.azure`, `~/.kube`, `~/.config`, `owner.env`; in the repo `.env*`, `*secret*`, `.claude/**`. On a repo linked with `kb-link-repo`, `guard.py` adds `private_paths` and the post budget from `unattended.json` |
| What it may write | triage and answer: nothing. Investigate: nothing (it runs tests). Fix: files in its worktree. `git --output` and `--ext-diff` are denied everywhere; `git commit`, `git push`, `gh` by the model are denied |
| What a post may say | a PreToolUse hook on every Slack tool (send, schedule, DM, canvas): this DM, the claimed thread (`thread_ts` and `message_ts`), no `reply_broadcast`, exactly the reply the script approved (no approved reply = no send), signed, no mentions except you, no secrets (token shapes, AWS keys, Slack webhooks, JWTs, values from the repo's `.env`), no promises. Hooks fail closed: a deny is exit 2, and no `jq` means deny |
| Edited after you reacted | inbox lane: declined by the script. Slack MCP lane: **prompt-only**, triage is told to decline an edited task, nothing checks it in code. React again after an edit |
| Only Slack loads | `MCP_DENY` (written by `find-self-dm.sh`) removes your other connectors from the bot's runs; act runs load no connector at all |
| Money | `--max-budget-usd` on every run from what is left: `WORK_BUDGET_USD` per message and `THREAD_BUDGET_USD` per thread, retries, posts and reactions included. A resumed session reports its whole total, so the script charges per-run deltas |
| Tested before trusted | `install.sh` arms the bot only if a Haiku run with exactly these settings is denied every canary: Read and `cat` of a secret in the repo, Read and `cat` of a file in your workbench, and `git log --output=<file>` |

### The fix route executes code

Investigate runs the repo's tests and fix writes a test and runs it. Tests are code: whatever is in `conftest.py`
or the test file runs on your laptop with your user's rights. The permission rules decide which commands the model
may start; they cannot see what a Python process does once it runs. **Where the OS sandbox is available it is the
real boundary**: `bot-settings.json` turns it on (`sandbox.enabled`, no unsandboxed retry, no allowed network
domains, reads outside the working directories blocked). It needs macOS, or Linux/WSL2 with `bubblewrap` **and**
`socat`; native Windows has none. Without it (`setup.sh --check` tells you) the bot's commands run unsandboxed and
the fences above are what you have. Keep `ALLOW_PR=false` unless you are watching.

## Check what it did

Every thread has one session: `claude --resume "$(cat kit/state/threads/<thread-ts>/session)"`, then ask "why?".
A fix has its own fresh session; the PR footer and `log/runs.jsonl` (`fix_session`) carry its `claude --resume`.
Same machine only. `claude --from-pr` lists sessions you started interactively; unattended `claude -p` sessions
are left out of the picker.

## After the lab

`./kit/cleanup.sh` removes what the bot kept: the worktrees and `agent/*` branches in the repo, claims, threads,
witness files, outbox, inbox, logs, the thread memory, and the bot's own session transcripts under
`~/.claude/projects` (they contain your drawers). It asks first; `--yes` skips the prompt, `--days N` keeps the
last N days. `owner.env`, `bot-settings.json` and the armed state stay.

## What's in `slack-bot/`

| Path | What |
|---|---|
| `setup.sh` | preflight (`--check`), one-time setup, weather-api or `--repo` |
| `kit/` | the bot: `watch.sh`, `work.sh`, `install.sh`, `cleanup.sh`, `find-self-dm.sh`, `slack-check.sh`, hooks, prompts, schemas, tests. `kit/README.md` for internals |
| `weather-api.bundle` | the practice repo with its history (`git clone weather-api.bundle`); six planted bugs, reports in `bugs/` |
| `weather-api/` | the same repo as files, to browse here (with `.env.example` in place of the bundle's fake `.env`) |
| `showcase/` | the trainer's demo: `SHOWCASE.md` runbook, messages, a demo workbench, `stage-reset.sh`, `fence-demo.sh` |
| slides | merged into the one W3 deck on the companion app (workshop.cosmohub.ro → Deck), so the polls, quiz and trainer scripts follow it |

Practise without Slack: `SOURCE=inbox` in `kit/owner.env`, drop a message file into `kit/inbox/`, read `kit/outbox/`.
Your drawers are used there too. That is also the lane for Codex and Copilot users (no Slack connector there).

## Tested and not

- Works on the owner's account, self-DM: the connector under `claude -p --permission-mode dontAsk` searches, reads,
  reacts and replies in a thread; `hasmy::robot_face:` returns only the reacted message, about 30 s after the reaction;
  threads (a reacted reply is the task, the whole thread is context, one session per thread); 👀/✅, with a retry when
  Slack drops the connection; answers from the workbench drawers in self-DM; `find-self-dm.sh`; `setup.sh` (both paths).
- Checked 6 Oct, Claude Code 2.1.288, Linux/WSL2: the claude.ai Slack connector's tools are still there under
  `--setting-sources project` (all 27 `mcp__claude_ai_Slack__*` tools, loaded as deferred tools; the `init` event lists
  no MCP servers because claude.ai connectors connect after it). `install.sh` on weather-api with a real workbench:
  all six canaries denied, ARMED, $0.03. The STOP hook blocked a live run's first tool call. Without the
  `git --output` deny, `git log --output=<file>` under `Bash(git log *)` does write the file.
  `kit/tests/slack-lane/run.sh` against the fake Slack server, with the new flags and exit-2 hooks: 9 of 10 checks
  passed (owner-only claims, witness, one signed reply in the thread, 🔕 respected, injection declined, nothing
  elsewhere, $0.27); the 10th was a stale expectation from before the "on it" post was dropped, since updated.
- Works offline: `sh kit/tests/run.sh`, 270 checks (hooks, fail-closed, STOP mid-run, claims, worker slots, threads,
  self-DM, drawers per lane, routes, read-only tool lists, the fresh fix session, cost deltas and caps, the
  red/green gate, install canaries, CRLF, cleanup).
- [T] The OS sandbox on a machine that has it (this Linux has bubblewrap but no socat, so it fell back to unsandboxed,
  as configured). Whether `uv run pytest` needs more than the re-opened `.venv`, uv cache and uv's Python under the
  read block.
- [T] Someone else's reaction excluded (needs a second account).
- [T] The `edited` field in the connector's output (the MCP lane's edit check is prompt-only).
- [T] Org policy for a normal participant: if send is set to `ask` for your workspace, `dontAsk` denies it.
- [T] macOS and native Windows with the hardened kit (the Windows Store `python3` stub is caught by `setup.sh --check`).
