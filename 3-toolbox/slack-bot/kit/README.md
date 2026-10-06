# w3-reception-kit

An owner-gated reception agent. **Only the owner starts it, anyone can stop it.**
Watch · Decide · Act within fences · Answer. Fixing is one of five routes, not the point.

```
watch.sh  one tick: PAUSED? armed? find approved messages, atomic claim (mkdir state/claims/<id>), work.sh
work.sh   triage (read-only, router schema)  ->  act (that route's tools only), same session
          the script checks the route, runs red-on-base / green-on-head, caps the diff, signs, guards, delivers
hooks/    watch-guard (exact search only) · witness (raw Slack responses) · slack-guard (where, what, who, 🔕)
```

Routes: **answer = cite · investigate = no edits · fix = red first · decline = template · escalate = owner only.**

## 1. Install (once per target repo)

```sh
cp owner.env.example owner.env      # set OWNER_ID, OWNER_NAME, SIGNATURE, TARGET_REPO, SOURCE
./install.sh                        # writes the denies, runs the self-test, arms the watcher
```

`install.sh` merges these denies into `<TARGET_REPO>/.claude/settings.json`: `Read(.env*)`, `Read(**/.env*)`,
`Read(**/*secret*)`, `Edit(.claude/**)`, `Write(.claude/**)`, `Bash(git push * main)`, `Bash(gh pr merge *)`,
`Bash(rm -rf *)`. Then a headless Haiku run tries to read two canary files (Read tool and `cat`). Only if both
are denied and nothing leaks does it write `state/armed`. `watch.sh` refuses to tick without it, and again
whenever the settings file changes.

## 2. Run once

File-inbox lane (no Slack needed, works for Codex/Copilot pairs too):

```sh
cp ../weather-api/bugs/03-bergen-sunny-in-rain.md inbox/
./watch.sh --wait                   # claims it and works it in the foreground
cat outbox/03-bergen-sunny-in-rain.md outbox/03-bergen-sunny-in-rain.pr.md
```

A message file may start with front matter: `reacted_by: <id>` (someone else's approval is ignored) and
`edited: true` (declined: changed after approval). Stop one thread: `touch inbox/<id>.no_bell`.

Slack lane: `SOURCE=slack` in `owner.env`. Each tick runs one Haiku search,
`in:#<channel> hasmy::robot_face: after:<yesterday>`, which only matches messages **you** reacted to,
checked by Slack with your token. A hit counts only if its `ts` is in Slack's raw response. *(Untested: see below.)*

## 3. Run on cron

```cron
*/1 9-18 * * 1-5  cd /path/to/w3-reception-kit && ./watch.sh >>log/cron.log 2>&1
```

No `sh`? Use the skill in a Haiku session: `claude --model haiku --plugin-dir /path/to/w3-reception-kit`, then
`/loop 1m /w3-reception-kit:watch`.

## 4. Stop

- Everything: `touch PAUSED` (in the reception folder). Running workers stop before their next step.
- One thread: 🔕 on the message (Slack) or `touch inbox/<id>.no_bell` (inbox).
- Clean up: `git -C <repo> worktree remove .worktrees/<id>` and `git -C <repo> branch -D agent/<id>`.

## Files you will look at

`log/reception.log` (what happened) · `log/runs.jsonl` (route, cost, minutes per thread) · `log/denies.log`
(every fence that fired) · `outbox/<id>.md` (signed reply) · `outbox/<id>.pr.md` (PR body with
`claude --resume <session>`) · `state/claims/<id>/` (triage.json, act.json, route.json, gate.txt).

## Tests

`tests/run.sh`: offline, no model, no Slack. Every hook fed fake stdin JSON (allow and deny), the inbox
watcher (arming, claims, idempotency, PAUSED, owner-only, concurrent ticks), `work.sh` against a fake
`claude` (routes, downgrades, red/green gate, diff cap, guard on the outbox, 🔕, memory), `install.sh`.

## Untested `[T]`

Everything that talks to Slack: tool names and argument names, `hasmy::` pass-through, posting, reactions,
the `edited` field, `slack-check.sh`. They are config in `owner.env` and marked `# [T] untested` in the code.

`tests/slack-lane/run.sh`: the Slack lane end to end against a **fake** Slack MCP server
(`tests/slack-lane/fake_slack.py`, stdio, registered as `claude_ai_Slack` so the real hook matcher applies).
Real `claude -p` runs on Haiku, about $0.25. It proves the kit's side (exact search, witness, owner-only hasmy,
claims, post run, live slack-guard). It cannot prove the real connector's names, payloads or org policy.
