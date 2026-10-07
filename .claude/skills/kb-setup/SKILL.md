---
name: kb-setup
description: First-run setup of this workbench KB. A 10-minute interview that fills 1-me/, NOW.md and the first work item, then offers safe personal defaults for ~/.claude. Run it by typing /kb-setup.
disable-model-invocation: true
---

# kb-setup

Goal: a working KB in one sitting, with safe defaults. Ask a few short questions at a
time. Don't lecture. Show what you wrote after each step.

## 0. Where am I

Confirm the KB path (`pwd`). If it isn't `~/workbench`, note the real path: step 5 uses it.

## 1. Profile (3–4 questions)

Role and team; what they work on; daily stack; how agents should work with them
(what to ask first, answer style, what never to do). Write `1-me/profile.md` under 30 lines.
Set `owner:` in `0-meta/kb.yaml`.

## 2. First work item

"What do you work on most this month?" Get the name, kind (product / project / repo),
repo path or URL, what's live, the next step, and what's blocked.
Copy `0-meta/templates/work-item/` to `2-work/<slug>/`, fill `README.md`, `state.md`, and a
first `log.md` line. Add a row to `2-work/README.md`.
**If the repo is local, read its README and build files to fill "How to work on it"
instead of asking.** Don't read source beyond that.

## 3. Team, terms, judgment (optional; offer to skip)

- Two or three people they work with and what each owns → `team.md` (names and roles only).
- Three internal terms an outsider wouldn't know → `glossary.md`.
- One question for `how-i-work.md`: "What do you correct most often when reviewing someone's code?"

## 4. NOW.md and clean-up

One row per active item, plus "this week"; set `updated:` to today. Ask whether to delete
`2-work/_example-orders-api/`. If yes, remove it and its rows in `2-work/README.md` and `NOW.md`.

## 5. Personal kit (ask first; never overwrite)

Explain in two lines what `3-toolbox/personal-kit/` does, then offer each piece:
- `~/.claude/CLAUDE.md`: **merge** the kit's lines into any existing file; fix the KB path.
- `~/.claude/settings.json`: **merge** the JSON (union of `deny`/`ask` lists, keep existing keys).
  Show the resulting diff and get a yes before writing. Offer `settings.strict.json` only if
  they want the sandbox; check `/sandbox` works on their machine first.
- `~/.claude/statusline.py`, its Perl twin `statusline.pl`, and `~/.claude/py` (the launcher that picks whichever runs here): copy.
- Global skills: copy `kb-capture`, `kb-decide` and `kb-vet` to `~/.claude/skills/`, so they work from any repo.

## 6. Check

Run `sh kb check` from the workbench root (it uses Python if there is one, Perl otherwise) and fix what it reports. Note the boot
cost it prints. That number is the point of the whole exercise. Then run `sh kb report` and show
the seven-drawer score: drawers 1–2 should now be filled; the rest come with `/kb-link-repo`.

## Done when

`sh kb check` reports no errors, `kb.yaml` has no TODO, and `NOW.md` lists a real item. If the check says
"Neither Python 3 nor Perl found", the guards are off on this laptop: stop and run `sh kb doctor`, which names the fix.
Close with the next two steps: `kb-link-repo` in their main repo, and `kb-capture` at the end
of their next working session.

## Don't

- Fill gaps with plausible guesses. Leave the placeholder or write `[unverified]`.
- Record secrets, customer data, or anyone's personal details.
- Write to `~/.claude/` without showing the change and getting a yes.
