# Showcase runbook · W3 part 2 (Bogdan)

Bogdan's own bot, in his DM with himself, on `weather-api`, with a small demo workbench (`workbench-demo/`, or a
real one). It was built the way the room will build theirs: by prompting, one fence at a time, fixed on real Slack.
It has more than the lab bot (investigate and fix routes, thread sessions, 🔕, a red/green gate); its code lives on
the trainer's laptop, not in this repo, so nobody runs it by mistake.

## Before the session

- The bot ticking in a side terminal, on weather-api, `NOW.md` from `workbench-demo/` (it names the W3 workshop).
- An empty DM with yourself, screen-shared, big font.
- The participants' path rehearsed once on a clean laptop: `BUILD.md`, prompts 0 to 6, about 25 minutes.

## The beats (about 8 minutes)

Write each message **in your DM with yourself**, then react 🤖. Search lag is about 30 s, plus one tick.

| Beat | You write | You should see |
|---|---|---|
| 1 | "Customer says Bergen shows sunny while it's pouring. Find out why." | 👀, then an investigation: rain codes 61-65 map to "sunny" at `src/weather_api/conditions.py:13`, since `5ba168d`. ✅ |
| 2 | Reply in that thread: "Write the test that would have caught it." React 🤖 on the reply | a `pytest.mark.parametrize` code block. Same session: it knows the cause |
| 3 | New message: "What am I working on, and what's my next step?" | an answer from `NOW.md` and `2-work/w3/state.md`, the drawers the script pasted in |
| 4 | Paste `messages/injection.md`'s text, react 🤖 | a polite no: no token, no @here, no other channel |

Resume: `claude --resume <session id from the bot's log>` and ask "why that line?".

## Then the room builds theirs

Open `BUILD.md` on screen and do prompt 0 live in your own Claude Code, so they see the agent read
`slack-bot.md` and say back what it will build. Then they go, prompt by prompt; walk the room at prompt 3 (the guard)
and prompt 4 (the canary): those are the two where people should read every line.

## Finale (the relay)

Self-DM bots can't be tagged, by design. Post a question in #w3-workshop and tag someone; they paste it into their
own DM, react 🤖, and post the answer back in your thread.

## After

Ask your agent to clean up what the bot kept (BUILD.md, last prompt), and do the same on the room's screens.
