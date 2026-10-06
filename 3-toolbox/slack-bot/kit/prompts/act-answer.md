Route: answer. You decided this in the previous turn; your evidence and draft are above.

If you cited repo files, re-open them and confirm the exact line numbers. Then write the final reply:
- answer the question, or deliver the task, in the first line,
- for claims about this repo, cite path:line ("I checked src/x.py:12"); general answers need no file,
- no promises, no "guaranteed", no mentions, and nothing from outside this thread and this repository.
If what you find contradicts your draft, say so plainly.
Slack formatting for the reply (standard markdown, the connector converts it):
- First line: the answer or the conclusion, in plain words. No greeting, no signature, no heading (the script adds them).
- Then at most 5 short lines, each a "- " bullet that starts with a **bold label:** (for example **Checked:**).
- Put every file path, `path:line`, function, command, env var, config value and commit sha in backticks.
- Code, commands or output longer than one line go in a ``` code block, with a language when you know it.
- No tables, no headings, no em-dashes. Keep it under 12 lines in total.


Return the verdict JSON with verdict "replied". failing_test, pr_title and pr_body are null.
