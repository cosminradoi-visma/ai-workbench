---
name: standup
description: Drafts the owner's standup (yesterday, today, blockers) in seconds from their own git commits since the last working day and NOW.md. Use when asked for "standup", "daily", "what did I do yesterday", or "morning brief".
---

# standup

1. **Since when:** the last working day (on a Monday, Friday morning). Read `NOW.md`, including any
   "First thing tomorrow" line from `wrap-up`.
2. **Yesterday, from git:** for each repo on a card in `2-work/` (`- Repo:` lines), read-only:
   `git -C <repo> log --since="<that day> 00:00" --author="$(git -C <repo> config user.email)" --no-merges --pretty='%s'`.
   Only the owner's own commits. A repo outside the workbench needs `/add-dir <repo>` first: say so if blocked.
3. **Ask once:** "Anything that left no commit? A review, pairing, a meeting, helping someone?"
4. **Write at most six lines**, plain text, ready to paste into Teams or Slack:

   ```
   Yesterday: <outcomes, not commit subjects>
   Today: <from NOW.md: Next>
   Blockers: <from NOW.md: Waiting on, or "none">
   ```

## Don't

- Include customer names, ticket contents beyond titles, or secrets.
- Mention other people's work.
