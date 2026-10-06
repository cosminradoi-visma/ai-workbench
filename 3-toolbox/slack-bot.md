---
updated: 2026-10-06
status: draft
verified: claude.ai Slack connector, Visma workspace, the owner's self-DM (5–6 Oct). Untested items are marked [T].
---

# A Slack bot that uses your workbench (W3, part 2)

Part 1 gave your agent its drawers: who you are, what you're on, how your repo works. Part 2 gives it a trigger.
You write to yourself in Slack, react 🤖, and your bot answers in the thread, using those drawers, on the
`weather-api` practice repo or on your own repo.

No Slack app and no bot token to get approved: it runs on your laptop through the **Slack MCP connector**
(`/mcp` shows `claude.ai Slack`), with your own login. Code, slides and the trainer's demo: [`slack-bot/`](slack-bot/).

## Set it up (about 15 minutes)

From your workbench clone:

```sh
cd 3-toolbox/slack-bot
sh setup.sh                      # kit + weather-api (with its git history) into ~/w3, both test suites
sh setup.sh --repo ~/code/mine   # or your own repo: run /kb-link-repo for it first (part 1)
cd ~/w3
./kit/find-self-dm.sh            # sends you ONE message; fills OWNER_ID, CHANNEL_ID, SELF_DM=true, MCP_DENY
./kit/install.sh                 # deny rules into the repo + a self-test; arms the bot only if it can't read secrets
./kit/watch.sh --wait            # one tick
```

Then in Slack, in your DM with yourself: write a question, react 🤖, tick again (or keep it running:
`while :; do ./kit/watch.sh; sleep 60; done`). Within a minute or two: 👀, one signed reply, ✅.

Needs: Claude Code v2.1.259 or later, the Slack connector connected in `/mcp`, `git`, `jq`, and `uv` for weather-api.
Your own repo: set `TEST_CMD` / `TEST_ALL_CMD` in `kit/owner.env` if it doesn't use `uv run pytest`, and give its
`AGENTS.md` an `## Operate` section (start, stop, check, test), like weather-api's.

## The loop

1. **Watch.** One search per tick: `in:<#your-DM> from:<@you> hasmy::robot_face: after:YYYY-MM-DD`.
   `hasmy::` returns only messages *you* reacted to, so Slack checks it is you. A hook pins the search to exactly
   that query, whatever the model types, and the script reads the hits from Slack's raw response.
2. **Claim.** 👀 on the message. One claim per reacted message, one worker per thread at a time.
3. **Decide.** A read-only run reads the **whole thread** (the message you reacted to is the task, everything
   before and after is context) and, in your DM, your drawers. It picks a route.
4. **Act.** A second run, same session, gets only that route's tools.
5. **Answer** in the thread, formatted for Slack, signed `🤖 <name>'s agent: <route>`, then ✅.

A 🤖 on a later message in the same thread continues the same session, so the bot remembers what it found.

| Route | When | Rule, checked by the script |
|---|---|---|
| answer | any question or task a reply can complete | claims about the repo cite a file that exists (or, in your DM, a workbench file) |
| investigate | looks like a bug, not proven | no edit tools |
| fix | a bug it can prove (off unless `ALLOW_PR=true`) | the new test fails on the old code and passes on the fix, full suite green, diff ≤ 200 lines / 5 files |
| decline | only when it would leak data | other Slack conversations, files outside the repo, personal files, secrets |
| escalate | security, customer data, production | mentions the owner only, proposes nothing |

Your 🤖 means "do it": it approves the task, never a data leak. A bot in a team channel should also decline
out-of-scope requests (`golden/example-must-decline.md`).

## Why your DM, and how the drawers get in

Rule 5 of [`safety.md`](safety.md): never private data, untrusted content and a way out in one session.
In your DM with yourself nobody else can write, so the untrusted-content leg is gone. The kit checks that in code:

- the search adds `from:<@you>`, and a hit counts only if Slack's own response shows the DM's only participant is you;
- the **script** reads `NOW.md`, `1-me/profile.md`, `how-i-work.md`, `glossary.md` and, with `WORK_ITEM`, one
  `2-work/<item>/state.md`, and hands them in as data. The model gets no file access to the workbench;
- every post is limited to that DM and that thread.

A message you paste into your DM (a customer email, a ticket) is still someone else's text: the fences below still apply.
In a team channel the leg comes back, so `SELF_DM=false` and the bot answers from the repo half only.

## Fences, and where each lives

| Fence | How |
|---|---|
| Only you start it | the pinned `hasmy::` search, plus the participants check in self-DM |
| Anyone can stop it | 🔕 on the thread (checked before every post), `touch kit/PAUSED`, or `touch .claude/STOP` in the repo (the same file `guard.py` uses) |
| What it may read | kit denies: `.env*`, `*secret*`, `.claude/**`. On a repo linked with `kb-link-repo`, `guard.py` adds `private_paths` and the post budget from `unattended.json` |
| What a post may say | a PreToolUse hook on every Slack tool (send, schedule, DM, canvas): this DM, the claimed thread, the reply the script approved, signed, no mentions except you, no secrets, no promises |
| What it may do | tools per route; `git push` to main, `gh pr merge` and `git commit` by the model are denied |
| Edited after you reacted | declined: react again |
| Only Slack loads | `MCP_DENY` (written by `find-self-dm.sh`) removes your other connectors from the bot's runs |
| Per-run caps | `--max-turns` and `--max-budget-usd` on every run |
| Tested before trusted | `golden/example-must-decline*.md`: injection, not the owner, edited |

## Check what it did

Every thread has one session: `claude --resume "$(cat kit/state/threads/<thread-ts>/session)"`, then ask "why?".
A fix PR carries the same command in its footer. Same machine only. `claude --from-pr` lists sessions you started
interactively; unattended `claude -p` sessions are left out of the picker.

## What's in `slack-bot/`

| Path | What |
|---|---|
| `setup.sh` | one-time setup, weather-api or `--repo` |
| `kit/` | the bot: `watch.sh`, `work.sh`, `install.sh`, `find-self-dm.sh`, `slack-check.sh`, hooks, prompts, schemas, tests. `kit/README.md` for internals |
| `weather-api.bundle` | the practice repo with its history (`git clone -b main weather-api.bundle`); six planted bugs, reports in `bugs/` |
| `weather-api/` | the same repo as files, to browse here |
| `showcase/` | the trainer's demo: `SHOWCASE.md` runbook, messages, a demo workbench, `stage-reset.sh`, `fence-demo.sh` |
| `slides/w3-part2.html` | the slides for part 2 (open in a browser; Guide mode has the speaker notes) |

Practise without Slack: `SOURCE=inbox` in `kit/owner.env`, drop a message file into `kit/inbox/`, read `kit/outbox/`.
That is also the lane for Codex and Copilot users (no Slack connector there).

## Tested and not

- Works on the owner's account, self-DM: the connector under `claude -p --permission-mode dontAsk` searches, reads,
  reacts and replies in a thread; `hasmy::robot_face:` returns only the reacted message, about 30 s after the reaction;
  threads (a reacted reply is the task, the whole thread is context, one session per thread); 👀/✅, with a retry when
  Slack drops the connection; answers from the workbench drawers in self-DM; `find-self-dm.sh`; `setup.sh` (both paths).
- Works offline: `sh kit/tests/run.sh`, 162 checks (hooks, claims, threads, self-DM, routes, the red/green gate, stop switches).
- [T] Someone else's reaction excluded (needs a second account).
- [T] The `edited` field in the connector's output.
- [T] Org policy for a normal participant: if send is set to `ask` for your workspace, `dontAsk` denies it.
- [T] Linux and Windows (tested on macOS).
