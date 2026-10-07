---
name: kb-tidy
description: Health check and clean-up of the workbench KB: runs the check, then reviews the knowledge with the owner (pages due for review, contradictions, facts buried in logs, orphans, work to archive). Use when asked to "tidy" or "check my KB", or when the session-start check reports problems.
---

# kb-tidy

A weekly ten minutes keeps the KB worth reading.

## Steps

1. **The mechanical checks** (you do them; there is no script). Limits are in `0-meta/kb.yaml`.
   - **Boot cost:** ask the user to type `/context` and read "Memory files". Over `boot_budget_tokens`:
     shorten `NOW.md`, `profile.md` or `AGENTS.md`; move detail one hop away.
   - **Indexes:** every folder's `README.md` lists every file in it; `INDEX.md` has a line per page.
   - **Links:** every relative link in a `.md` file points at a file that exists.
   - **Fresh:** `NOW.md` and each `state.md` have an `updated:` date within `stale_days`, and stay under
     `now_max_lines` / `state_max_lines`. Stale: ask what changed, then update. Never just bump the date.
   - **Never in here:** search for likely secrets (`ghp_`, `github_pat_`, `sk-`, `AKIA`, `xox`, `BEGIN` … `PRIVATE KEY`,
     `password=` in a connection string), and for hidden Unicode (zero-width or bidirectional characters).
     Show the line and remove it. For a real secret, tell the user to rotate it now: it is in git history.
   - **Skills:** each `description:` under `skill_description_max` characters.
2. Report those in one short list before moving on.
3. **Read the knowledge, not just the files** (the check can't do this part):
   - **Due for review:** `4-know/` pages whose `review:` cadence has passed since `updated:`
     (monthly 30 days, quarterly 90). Ask "still true?" one page at a time; update, or set `status: archived`.
   - **Contradictions:** two pages that disagree (an owner, a command, a rule). Show both; ask which is right.
   - **Buried knowledge:** facts sitting only in a `log.md` or `state.md` that will outlive the task.
     Propose promoting them to `4-know/` (see `kb-capture` step 5).
   - **Orphans:** a `4-know/` page no work item, index or other page links to. Link it or archive it.
   - **Duplicates:** two pages about the same thing. Keep one; link from the other.
   - **`assumed` pages** an agent relied on this week: offer to check them against the source and mark them `verified`.
4. **Archive what ended:** a work item with `status: done`, or a project with nothing next for a month. Follow
   "Projects, areas, archive" in `0-meta/conventions.md`; take it out of `NOW.md`.
5. **`INDEX.md`:** one line for every live page, none for moved or deleted ones.
6. Go through `0-meta/audit.md`: fix what you can now, then delete those rows. Prune learnings no
   longer true and `inbox/` leftovers.
7. Report what is left. Finish with `kb-score`: name the emptiest drawer and the one step that would fill it.

## Don't

- Delete content the user hasn't confirmed is obsolete.
