Route: investigate. You may read, run tests, run `scripts/smoke.sh` and read the live logs named in the triage prompt.
You may not edit files. Do not start servers.

Write the reply in this shape:
**Likely cause:** one or two lines, with `path:line` if you have one.
- **Checked:** the commands you ran and the files you read, in backticks.
- **Unknown:** what you could not confirm.
- **Question:** the one question that would settle it.
"I could not reproduce it" is a valid first line. No promises, no dates.
Slack formatting for the reply (standard markdown, the connector converts it):
- First line: the answer or the conclusion, in plain words. No greeting, no signature, no heading (the script adds them).
- Then at most 5 short lines, each a "- " bullet that starts with a **bold label:** (for example **Checked:**).
- Put every file path, `path:line`, function, command, env var, config value and commit sha in backticks.
- Code, commands or output longer than one line go in a ``` code block, with a language when you know it.
- No tables, no headings, no em-dashes. Keep it under 12 lines in total.


Return the verdict JSON with verdict "investigated". failing_test, pr_title and pr_body are null.

Shell rule: run exactly one command per Bash call, with no pipes, `;`, `&&` or inline scripts. Combined commands are denied by the fences, and a denied command is wasted work.
