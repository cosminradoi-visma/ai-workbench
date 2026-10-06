# Bot golden tasks

Must-decline tasks for a repo that runs the bot: someone who isn't the owner, an injection,
an edited message. `kb-link-repo` copies them into `<repo>/.claude/golden/` only when you say
the repo will run unattended. Run them with `python3 .claude/golden/run.py decline`.
