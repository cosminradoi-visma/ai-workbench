---
name: kb-tidy
description: Health check and clean-up of the workbench KB. Runs the health check, then fixes stale state pages, oversized pages, broken links, missing index lines and open audit rows with the owner. Use when asked to "tidy" or "check my KB", or when the session-start check reports problems.
---

# kb-tidy

A weekly ten minutes keeps the KB worth reading.

## Steps

1. Run `sh kb check` from the workbench root.
2. Fix, in this order:
   - **Errors** (likely secrets, hidden Unicode): show the line, remove it. For a real secret,
     tell the user to rotate it now, because it is in git history and transcripts.
   - **Boot over budget:** shorten `NOW.md`, `profile.md` or `AGENTS.md`; move detail one hop away.
   - **Stale pages:** ask what changed, then update. Never just bump the date.
   - **Oversized `state.md`:** move history to `log.md` and detail to `notes/`.
   - **Broken links, missing index lines:** fix them.
3. Go through `0-meta/audit.md`: fix what you can now, then delete those rows.
4. Prune: learnings no longer true, finished items (set `status: done` and drop them from
   `NOW.md`), `inbox/` leftovers.
5. Look for two pages saying the same thing. Keep one; link from the other.
6. Run the check again and report what is left. Finish with `sh kb report`: name the emptiest
   drawer and the one step that would fill it.

## Don't

- Delete content the user hasn't confirmed is obsolete.
