# Golden tasks

A handful of real, small jobs with a check the agent can't influence. Run them after you change
`AGENTS.md`, a skill, a rule, a hook or the model, and see whether the agent got better or worse,
and what it cost.

- `run.sh`: run this (`sh .claude/golden/run.sh`, or `--list`, `--keep`, or part of a task name). It starts `run.py`,
  or its Perl twin `run.pl` on a laptop without Python. Every task gets a clean worktree of `HEAD`, a headless Claude
  run, then the check.
- `example.md`: the task format. It **fails until you replace it** (it needs `src/text.py` and a test).
- `example-must-decline.md`: the decline format: a polite no, and no files touched.

Good golden tasks: bugs you already fixed (you know the answer), one sitting each, a check that fails
before and passes after, and `protect:` on the tests so passing can't mean "edited the test".
