---
name: kb-capture
description: Saves what this session learned into the workbench KB (state, log, decisions, learnings) so the next session starts without re-exploring. Use at the end of meaningful work, or when asked to "capture", "wrap up", "save to the KB" or "update my KB".
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
3. **`log.md`: append one line**, newest first: `YYYY-MM-DD — what happened (link)`.
4. **Decisions:** for each real choice between alternatives made this session, follow `kb-decide`.
5. **Learnings:** a lesson that applies beyond this item goes in `1-me/learnings.md`, one line.
   If the user corrected your judgment, ask whether it belongs in `1-me/how-i-work.md`.
6. **`NOW.md`:** update this item's row; add or remove rows for items started or finished.
7. **Contradictions:** if the session proved a page wrong, fix it. If you can't, add a row to `0-meta/audit.md`.
8. Show a short summary: the files changed, one line each.

## Done when

A fresh session could continue from `NOW.md` and `state.md` alone.

## Don't

- Paste transcripts, diffs or logs. Summarise to what the next session needs.
- Record secrets, personal data, or anything the user said was private.
