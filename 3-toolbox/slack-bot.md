---
updated: 2026-10-06
status: draft
verified: claude.ai Slack connector, Visma workspace, owner's self-DM only (5 Oct). Untested items are marked [T].
---

# A Slack bot on the Slack MCP connector (W3 lab path)

The bot answers in Slack as you, from your repo. No Slack app and no bot token to get approved:
it runs on your laptop through the **Slack MCP connector** in Claude Code (`/mcp` shows `claude.ai Slack`),
with your own user token. The fences are the ones in `safety.md` under "Agents that run unattended";
this page is how to wire them for Slack.

## The loop

1. **Watch**: a cheap model (Haiku) runs one search per tick, with your reaction as the trigger:
   `in:<#CHANNEL_ID> hasmy::robot_face: after:YYYY-MM-DD`. `hasmy::` returns only messages *you* reacted to,
   so Slack checks it is you, not the model. A neighbour's reaction never shows up.
2. **Claim**: one claim per message (`mkdir state/claims/<ts>` is atomic), so it never answers twice.
3. **Decide**: a first run, read-only, picks a route: answer (cite `file:line`), investigate (no edits),
   fix (only with a failing test first), decline, escalate (owner only).
4. **Act**: a second run gets only that route's tools. A message cannot talk its way from "answer" into "push".
5. **Answer** in the thread, signed: `🤖 <name>'s agent: ...` and `React 🔕 to stop me in this thread.`

## Fences, and where each lives

| Fence | How |
|---|---|
| Only the owner starts it | the `hasmy::` search above; the model can only nominate a message the search returned |
| Anyone can stop it | 🔕 on the thread (checked before every post), or `touch .claude/STOP` |
| Repo half only | `.claude/unattended.json` → `private_paths` (guard.py) |
| Post budget | `.claude/unattended.json` → `send_tools` + `max_sends_per_hour`. The pattern covers schedule, DM and canvas tools too: each can post or leak |
| What a post may say | a PreToolUse hook on `mcp__.*[Ss]lack.*`: only the claimed thread, signed, no mentions except the owner, no secrets |
| Edited after you reacted | decline and ask the owner to react again |
| Tested before trusted | `golden/example-must-decline*.md`: out of scope, injection, not the owner, edited |

The connector has more ways to post than "send": schedule a message, open a DM, write a canvas.
Guard all of them, not only `send_message`.

## Run it

- `claude -p --model haiku --permission-mode dontAsk --allowedTools <the search tool> --max-turns 3 --no-session-persistence`
  for the watch tick, on a 1-minute cron, never `/loop` in a long session (its context grows every tick).
- Read `total_cost_usd` from `--output-format json` and stop above your budget.
- Practise offline first: the same loop reading `inbox/*.md` instead of Slack.

The full example (watcher, router, hooks, a demo repo with planted bugs) is Bogdan's `w3-reception-kit`
and `weather-api` from the W3 workshop.

## Tested and not

- Works (owner's account, self-DM): `hasmy::robot_face:` returns only the reacted message, about 30 s after the
  reaction; `claude -p` with the connector can search, read, react and reply in a thread under `dontAsk`;
  reaction user ids are readable with `slack_get_reactions`.
- [T] Someone else's reaction excluded (needs a second account).
- [T] The `edited` field on a message in the connector's output.
- [T] Org policy for a normal participant: if send is set to `ask` for your workspace, `dontAsk` denies it.
- Every connected connector loads into every headless run: keep `/mcp` small for the bot's runs.
