---
name: wrap-up
description: End-of-day shutdown in two minutes: today's own commits and the work that left none, logged as impact; brag-worthy items proposed; NOW.md set up for tomorrow. Use when asked to "wrap up", "end of day", "shutdown", "done for today" or "log my day".
---

# wrap-up

A daily work journal (after Joel Hawksley, GitHub): a few lines of impact at the end of every day.
It makes invisible work visible, reviews write themselves, and it is a clean end to the working day.

1. **Today, from git:** for each repo on a card in `2-work/` (`- Repo:` lines), read-only:
   `git -C <repo> log --since=midnight --author="$(git -C <repo> config user.email)" --no-merges --pretty='%s'`.
   A repo outside the workbench needs `/add-dir <repo>` first.
2. **Ask once:** "What did you do today that left no commit? Reviews, pairing, unblocking someone, a decision?"
   That work matters most and is the easiest to forget.
3. **Log impact, not activity:** one line per item in its `2-work/<item>/log.md` ("Fixed rounding at the .5
   boundary: refunds now match the original total", not "3 commits"). Update each touched `state.md` (`kb-capture`
   rules: overwrite, don't append). Anything that will outlive the task goes to its `4-know/` page.
4. **Brag doc:** propose at most two entries for `1-me/brag.md`, as "did X, which made Y possible". Write them
   only after a yes.
5. **Tomorrow:** in `NOW.md`, set this week's line and add `First thing tomorrow: <one concrete step>`, so tomorrow's
   `standup` and session start from it.
6. End with one line: "Done for today." Nothing else.

## Don't

- Record secrets, customer data or anyone's personal details.
- Write about colleagues' work beyond "paired with <name> on <thing>".
