# Showcase runbook · W3 part 2 (Bogdan)

Bogdan's own bot, in his DM with himself, on `weather-api`, with a small demo workbench (`workbench-demo/`,
or your real one). The beats match the slides: 1 · the real thing, 1 · resume, 6 · the fences, finale.

## Set up, once (from `3-toolbox/slack-bot/`)

```sh
sh setup.sh                          # kit + weather-api into ~/w3
cp -R showcase ~/w3/ && cd ~/w3/showcase
cp owner.env.example owner.env
OWNER_ENV=$PWD/owner.env ../kit/find-self-dm.sh   # one message to yourself; fills OWNER_ID, CHANNEL_ID, MCP_DENY
OWNER_ENV=$PWD/owner.env ../kit/install.sh        # must say ARMED
./stage-reset.sh
```

Watcher during the session, in a side terminal (the wall goes in a second one: `./wall.sh`):

```sh
export OWNER_ENV=$PWD/owner.env
while :; do ../kit/watch.sh; sleep 30; done
```

## The beats (slide 5, about 8 minutes)

Write each message **in your DM with yourself**, then react 🤖. Search lag is about 30 s, plus one tick.

| Beat | You write | You should see |
|---|---|---|
| 1 | "Customer says Bergen shows sunny while it's pouring. Find out why." | 👀, then **investigate**: rain codes 61-65 map to "sunny" at `src/weather_api/conditions.py:13`, since `5ba168d`. ✅ |
| 2 | Reply in that thread: "Write the test that would have caught it." React 🤖 on the reply | **answer** with a `pytest.mark.parametrize` code block. Same session: it knows the cause |
| 3 | New message: "What am I working on, and what's my next step?" | **answer** from `NOW.md` and `2-work/w3/state.md`: slides half done, next rehearse the setup lab |
| 4 | Optional: react 🔕 on a fresh 🤖'd message before it answers | 👀, then no reply (wall: `not sent, muted`) |

Resume (slide 7): `claude --resume "$(cat state/threads/<thread-ts>/session)"` and ask "why that line?".

Fences (slide 24): paste `messages/injection.md`'s text into your DM, react 🤖. The bot declines; then run
`./fence-demo.sh` on the wall: token, @here, other thread, promise, all denied by `slack-guard.sh`.

Fix demo, only if rehearsed: `ALLOW_PR=true` in `owner.env`, paste `messages/bergen.md`. Expect red on base,
green on head, a PR body in `outbox/` with the resume footer (no remote = no GitHub PR).

## Rehearse without Slack (inbox lane)

`SOURCE=inbox` in `owner.env`, then `cp messages/<file>.md inbox/ && ../kit/watch.sh --wait` and read `outbox/`.
`messages/README.md` lists what each message should produce.

## Finale (the relay)

Self-DM bots can't be tagged, by design. Post the question in #w3-workshop, tag the person; they paste it into their
own DM, react 🤖, and post the answer back in your thread. Keep your own watcher on: your bot answers the questions
you relay to yourself the same way.

## Reset

`./stage-reset.sh`: removes agent worktrees and `agent/*` branches in weather-api, clears claims, outbox, logs and
inbox, restores the thread memory from `memory/threads.seed.jsonl`. Local only.
