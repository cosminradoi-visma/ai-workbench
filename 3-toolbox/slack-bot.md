---
updated: 2026-10-07
status: draft
verified: the design and the lessons, on the claude.ai Slack connector, a company workspace, the trainer's self-DM (5–7 Oct). The build prompts, run in order by a fresh agent (7 Oct). Untested items are marked [T].
---

# A Slack bot that uses your workbench (W3, part 2)

Part 1 gave your agent its drawers: who you are, what you're on, how your repo works. Part 2 gives it a trigger.
You write to yourself in Slack, react 🤖, and your bot answers in the thread, using those drawers, on the
`weather-api` practice repo or on your own repo.

No Slack app and no bot token to get approved: it runs on your laptop through the **Slack MCP connector**
(`/mcp` shows `claude.ai Slack`), with your own login.

**You don't run our code: there is none.** You build the bot by prompting your own agent, one file at a time, and
read each file before it runs: [`slack-bot/BUILD.md`](slack-bot/BUILD.md). This page is the context your agent
reads first: what to build, which fences, and what we learned building the trainer's bot on real Slack.

**Never paste customer data, payroll or personal data into your DM for the bot.** Practise on weather-api's bug
reports, your own code questions and your own notes.

## What you build

Four files and two tests in a folder of your own (`~/w3/my-bot`), about 250 lines plus the tests:

| File | Job |
|---|---|
| `tick.sh` | one round: find your 🤖s, answer each one. Holds your IDs and paths at the top (they are not secrets) |
| `hooks/slack-guard.sh` | a PreToolUse hook: the only Slack calls the bot may make |
| `bot-settings.json` | what the bot's runs may read and run, and the hook |
| `prompts/answer.md` | how it answers |
| `tests/guard-test.sh` | fake inputs into the guard: what must pass, what must be denied |
| `tests/canary.sh` | the bot, with its settings, tries to read your secrets and drawers: every try must be denied |

The loop, each tick (every minute, from `while :; do sh tick.sh; sleep 60; done`):

1. **Stop?** A `STOP` file in the bot folder: do nothing. (Ctrl-C stops a loop you're watching.)
2. **Find.** One small run (Haiku) searches Slack. The guard replaces whatever query it types with exactly
   `in:<#your-DM> from:<@you> hasmy::robot_face: after:<yesterday>`. `hasmy::` returns only messages **you**
   reacted to, so Slack itself checks that it is you.
3. **Claim.** Each hit's ts goes into `done.txt` **before** any work, so a crash never answers twice.
4. **Answer.** One run per hit, in the repo, read-only: 👀 on your message, read the whole thread (the message you
   reacted to is the task, everything before and after is context), one signed reply in the thread, ✅.

## Why your DM, and how the drawers get in

Rule 5 of [`safety.md`](safety.md): never private data, untrusted content and a way out in one session.
Your drawers are the private data. The bot holds them anyway, and this is why that is allowed.

**The self-DM makes the untrusted-content leg smaller, it does not remove it.** Nobody else can post in your DM
with yourself, but other people's words still get in: a message you forward or paste, a link that unfurls. So the
bot treats every message as data, and the exception holds **only because the way out is closed**:

- the guard lets it post only in that DM, only in the claimed thread, signed, with no mentions and no token shapes;
- no WebSearch or WebFetch in any run that has your drawers;
- **the model never reads the workbench**: `tick.sh` reads `NOW.md` and `1-me/profile.md` and pastes them into the
  prompt; `bot-settings.json` denies the model every read of the workbench folder.

A bot in a team channel brings the untrusted leg back in full: it never gets the drawers. That is not part of the lab.

## Fences

| Fence | In your bot | How |
|---|---|---|
| Only you start it | yes | the pinned `hasmy::` search with `from:<@you>`, in your DM |
| What it may say, and where | yes | `slack-guard.sh` on every Slack tool: search pinned, read only the claimed thread, 👀/✅ only, send only to the claimed thread, signed, no mentions, no `<!here>`, no links, no token shapes. Everything else denied (exit 2). No `jq` = deny |
| What it may read | yes | `bot-settings.json`: denies `.env*`, `*secret*`, the workbench, `~/.ssh`, `~/.aws`, `~/.config`, `~/.claude`; no edits, no web |
| Not your personal setup | yes | every bot run uses `--setting-sources project`: your own allow rules and hooks in `~/.claude` don't apply |
| Anyone can stop it | yes | `touch ~/w3/my-bot/STOP`, checked at the start of every tick |
| Caps per run | yes | `--max-turns` and `--max-budget-usd` on every run |
| Never twice | yes | claim in `done.txt` before answering |
| Proved before trusted | yes | `tests/guard-test.sh`, and `tests/canary.sh`: the bot, with its settings, tries Read, `head`, `sed` and `grep` on `.env`, `NOW.md` and `~/.ssh`, and must be denied every time |
| 🔕 silences a thread | stretch | `slack_get_reactions` on the thread before the reply |
| One session per thread | stretch | `--session-id` on the first 🤖, `--resume` on the next one in that thread |
| Hits from Slack, not from the model | stretch | a PostToolUse hook saves the raw search result; the script takes the hits from it |
| Only Slack loads | stretch | `--disallowedTools mcp__<server>` for each of your other connectors |
| Investigate, fix, PR | trainer's bot | more routes, a red-on-old/green-on-new gate, worktrees. Not in the lab |

## What we learned on real Slack

Each line cost a failed run. Give them to your agent with the build prompts.

- **Connector tools are deferred.** With many tools loaded a run sees only their names: it must call ToolSearch
  (`select:<tool>`) before it can use one. Haiku told only "search Slack" didn't, returned no hits, and the tick
  looked healthy. Say "load it with ToolSearch first", and log "never searched" apart from "nothing found".
- **DMs need `slack_search_public_and_private`.** `slack_search_public` doesn't see your DM.
- **The search finds a reaction about 30 s after you add it.** `after:` takes a date and excludes it: use yesterday.
- **Replace the query, don't check it.** Haiku rewrote `from:<@U…>` and a strict check denied every tick. A
  PreToolUse hook can return `permissionDecision: "allow"` with `updatedInput`, which **replaces the whole input**.
- **Search results carry "context" messages** (indented, before and after each hit). Their ts are not hits; only
  the unindented `Message_ts:` lines are. The model once reported 0 hits when Slack had 1: the stretch fence reads
  the raw result.
- **The thread is in the permalink**: `?thread_ts=<first message>`. A reply's own ts is the task; the thread's first
  message is what `slack_read_thread` and `thread_ts` need.
- **The connector can't delete, edit or remove a reaction.** So no "on it" message: 👀 when picked up, ✅ when
  answered. Adding the same reaction twice succeeds silently.
- **A link in a reply is a way out.** Slack fetches it to show a preview, so data in its query string leaves.
  The guard denies `http` in replies; cite files as `path:line`.
- **Slack drops the connection now and then.** A missing ✅ is usually that: retry the reaction once.
- **`slack_send_message` takes standard markdown** (`**bold**`, `` `code` ``, code blocks) and converts it. Slack adds
  "*Sent using* Claude" to each post.
- **Name the connector.** With two Slack connectors (claude.ai and a company gateway) the agent may pick the other
  one, and your guard matches `mcp__claude_ai_Slack__` only.
- **Every connector you have loads into each run.** With about 200 tools, one run spent its budget before answering.
  The stretch fence turns the others off.
- **Don't use `--bare`**: it skips your claude.ai login. `--setting-sources project` keeps your settings out and the
  connector still loads (checked on 2.1.288). Plugins you installed still load their hooks (seen on 2.1.292):
  `dontAsk` denies their tools, but check what they inject.
- **`git log --output=<file>` writes a file** even under `Bash(git log *)`: deny `--output`. `git diff --no-index`
  reads any file on disk, and `git show HEAD:.env` reads a committed one: deny those too.
- **`git log -p` prints a committed secret without naming the file**, and no rule can catch that. The guard's token
  check is the last net. Don't point the bot at a repo with real secrets in its history (weather-api's are fake).
- **Read-only shell commands run without an allow rule.** The bot's `cat`, `sed` and `grep` ran in the repo though
  only `git` and `ls` were allowed: Claude Code approves read-only commands itself. The Read denies still blocked
  `head`, `sed` and `grep` on `.env`, the workbench and `~/.ssh` (12 of 12, 2.1.292). Test it with a control file.
- **A canary only counts if the settings deny it.** A model that refuses to read `.env` because `AGENTS.md` says so
  proves nothing: tell it to call the tool, and check `permission_denials` in the JSON output.
- **Workbench guards block `.env` names**, rightly. The bot's IDs and paths are not secrets: keep them at the top of
  `tick.sh`.
- **Headless sessions don't show in `claude --from-pr`'s picker.** Log the session id and use `claude --resume <id>`.

## Check what it did

`log/runs.log` has one line per run with its session id: `claude --resume <id>`, then ask "why?". Same machine only.

## After the lab

Ask your agent (BUILD.md, last prompt) to delete `done.txt`, `log/` and the bot's session transcripts under
`~/.claude/projects` for the repo folder: they contain your drawers.

## On Windows

Use **Git Bash** (it comes with Git for Windows, which Claude Code needs) and the prompts work as written.
In PowerShell, run the bot with `& "$env:ProgramFiles\Git\bin\sh.exe" tick.sh`. [T] Not yet run end to end on Windows.

## What's in `slack-bot/`

| Path | What |
|---|---|
| `BUILD.md` | the prompts, in order |
| `weather-api.bundle` | the practice repo with its history (`git clone weather-api.bundle`); six planted bugs, reports in `bugs/` |
| `weather-api/` | the same repo as files, to browse here |
| `golden/` | must-decline examples for a repo that runs a bot: copy one into the repo's `.claude/golden/` |
| `showcase/` | the trainer's demo: `SHOWCASE.md`, the messages, a demo workbench |

## Tested and not

- On the trainer's account, self-DM: the connector under `claude -p --permission-mode dontAsk` searches, reads,
  reacts and replies in a thread; `hasmy::robot_face:` returns only the reacted message; threads; 👀/✅; answers
  from the drawers.
- The build prompts, run in order by a fresh agent on macOS (7 Oct), prompts 0 to 6: guard test 44/44, the canaries
  12/12 denied, then a real 🤖 in the DM answered with 👀, one signed reply (`units.py:9`) and ✅; the guard log shows
  exactly those five calls. Four prompt gaps found on the way are fixed in BUILD.md.
- [T] Prompt 7 (stretch), the cleanup prompt and the file lane.
- [T] Someone else's reaction excluded (needs a second account).
- [T] Org policy for a normal participant: if send is set to `ask` for your workspace, `dontAsk` denies it.
- [T] Linux and Windows.
