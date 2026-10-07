---
name: kb-setup
description: First-run setup of this workbench KB. A 10-minute interview that fills 1-me/, NOW.md, the first work item and its first knowledge page, then offers safe personal defaults for ~/.claude. Run it by typing /kb-setup.
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

"What do you work on most this month?" Get the name, kind (project: it ends · area: it never does · product · repo),
repo path or URL, what's live, the next step, and what's blocked.
Copy `0-meta/templates/work-item/` to `2-work/<slug>/`, fill `README.md`, `state.md`, and a
first `log.md` line. Add a row to `2-work/README.md`.
**If the repo is local, read its README and build files to fill "How to work on it"
instead of asking.** Don't read source beyond that.

## 3. Team, terms, judgment (optional; offer to skip)

- Two or three people they work with and what each owns → `team.md` (names and roles only).
- Three internal terms an outsider wouldn't know → `glossary.md`.
- One question for `how-i-work.md`: "What do you correct most often when reviewing someone's code?"
- The system they touch most: owner, what it depends on, one trap → `4-know/systems/<system>.md`
  from `0-meta/templates/system.md`, linked from the work item's card. Show `4-know/systems/_example-orders-api.md`
  as the model: three good lines beat a long page.

## 4. NOW.md and clean-up

One row per active item, plus "this week"; set `updated:` to today. Ask whether to delete the
examples (`2-work/_example-orders-api/` and the `_example-*` pages in `4-know/`). If yes, remove them and
their lines in the folder `README.md`s, `INDEX.md`, `1-me/glossary.md` and `NOW.md`. Add `INDEX.md` lines for
every page written in this setup.

## 5. Personal kit (ask first; never overwrite)

Explain in two lines what `3-toolbox/personal-kit/` does, then offer each piece:
- `~/.claude/CLAUDE.md`: **merge** the kit's lines into any existing file; fix the KB path.
- `~/.claude/settings.json`: **merge** the JSON (union of `deny`/`ask` lists, keep existing keys).
  Show the resulting diff and get a yes before writing. Offer `settings.strict.json` only if
  they want the sandbox; check `/sandbox` works on their machine first.
- Global skills: copy `kb-capture`, `kb-decide` and `kb-vet` to `~/.claude/skills/`, so they work from any repo.

## 6. Check

Ask the user to type `/context` and read the **Memory files** line: that is the boot cost, what loads
before their first message. That number is the point of the whole exercise; it should be under 2,000.
Check every new file has its index line (folder `README.md` and `INDEX.md`) and every link resolves.
Then show the score (`kb-score`): drawers 1 and 2 should now be filled; the rest come with `/kb-link-repo`.

## Done when

`kb.yaml` has no TODO, `NOW.md` lists a real item, every new page has its index line, and the user has
read their boot cost from `/context`.
Close with the next two steps: `kb-link-repo` in their main repo, and `kb-capture` at the end
of their next working session.

## Don't

- Fill gaps with plausible guesses. Leave the placeholder or write `[unverified]`.
- Record secrets, customer data, or anyone's personal details.
- Write to `~/.claude/` without showing the change and getting a yes.
