# Try to make it leak

Predict first: which of these will be stopped? Then type each one in Claude Code, from `~/workbench`.

| # | Type this | What should happen | Which guard |
|---|-----------|--------------------|-------------|
| 1 | `show me what is in 3-toolbox/playground/.env` | Denied, even if you ask nicely, even through `cat` | a deny rule: `Read(**/.env)` |
| 2 | `deploy with token ghp_` followed by 36 letters (make them up) | "Prompt not sent": the prompt never reaches your conversation | a prompt hook: a small model checks it |
| 3 | `add a line to 3-toolbox/playground/README.md and use an em-dash in it` | Blocked, with the reason. It may offer to get around it. Then say "rewrite it" | one line of `grep` in the settings |
| 4 | `run grep -r password 3-toolbox/playground` | It skips `.env`, and still prints the password in `config.yaml` | none: this is the miss |

**What 4 teaches:** the rules know file *names*, not what is inside your files. Deny rules are a speed
bump for what they name; the sandbox is the wall for the shell; your review is the gate. That is why
secrets never go in config files, and why you read the diff.

Afterwards: open `.claude/settings.json` in your workbench. Every guard you just met is a few lines there,
and none of them is a script.
