---
name: kb-capture
description: Saves what this session learned into the workbench KB (state, log, decisions, and lasting knowledge promoted to 4-know/) so the next session starts without re-exploring. Use at the end of meaningful work, or when asked to "capture", "wrap up", "save to the KB" or "update my KB".
---

# kb-capture

The habit that makes the KB worth having. Aim for two minutes.

**The KB root:** the current repo if it has `0-meta/kb.yaml`; otherwise the workbench path
named in `~/.claude/CLAUDE.md` (default `~/workbench`). Find the item in `2-work/README.md`.
If it isn't there, offer to create it from `0-meta/templates/work-item/`.

## Steps

1. **What changed this session:** shipped, decided, discovered, blocked. Use the conversation
   and, in a repo, `git log --oneline` and `git diff --stat` since the session started.
2. **`state.md`: overwrite, don't append.** Make "Right now", "Next" and "Waiting on" true *now*.
   Add a gotcha only if it cost real time. Update `updated:` and `verified:` (what you checked).
   Stay under 80 lines; move detail into `notes/` and link it.
3. **`log.md`: append one line**, newest first: `YYYY-MM-DD: what happened (link)`.
4. **Decisions:** for each real choice between alternatives made this session, follow `kb-decide`.
5. **Promote what lasts.** Ask: what from this session will still be true after this task?
   Move each such fact to its page in `4-know/` (create it from `0-meta/templates/` if missing),
   and leave a link on the item's card under "What we know about it":
   - a system's owner, dependency, environment or trap → `4-know/systems/<system>.md`
   - what a term really means here → `4-know/domain/<concept>.md`, titled with the claim
   - a procedure done twice → `4-know/playbooks/<task>.md`
   - something that broke → `4-know/incidents/YYYY-MM-<slug>.md`
   - how someone wants to work, what they own → `4-know/people/<name>.md` (work facts only)
   Update the page rather than adding a second one. New page → one line in its folder's `README.md`
   and in `INDEX.md`. Propose the promotions in one list and write them after a yes.
6. **Learnings:** a lesson about how *you* work, beyond any one system, goes in `1-me/learnings.md`.
   If the user corrected your judgment, ask whether it belongs in `1-me/how-i-work.md`.
7. **`NOW.md`:** update this item's row; add or remove rows for items started or finished.
   An item that ended: offer to archive it (`0-meta/conventions.md`, "Projects, areas, archive").
8. **Contradictions:** if the session proved a page wrong, fix it. If you can't, add a row to `0-meta/audit.md`.
9. Show a short summary: the files changed, one line each.

## Done when

A fresh session could continue from `NOW.md` and `state.md` alone, and nothing learned today
that outlives the task is left only in `log.md`.

## Don't

- Paste transcripts, diffs or logs. Summarise to what the next session needs.
- Record secrets, personal data, or anything the user said was private.
