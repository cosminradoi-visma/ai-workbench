# Golden tasks

A handful of real, small jobs with a check the agent can't influence. Run them after you change
`AGENTS.md`, a skill, a rule, a hook or the model, and see whether the agent got better or worse,
and what it cost.

- Run them with `/golden-run` (the skill in `.claude/skills/golden-run/`): every task gets a clean worktree of
  `HEAD`, a fresh headless agent, then the check. Part of a name runs only those.
- `example.md`: the task format. It **fails until you replace it** (it needs `src/text.py` and a test).
- `example-must-decline.md`: the decline format: a polite no, and no files touched.

Good golden tasks: bugs you already fixed (you know the answer), one sitting each, a check that fails
before and passes after, and `protect:` on the tests so passing can't mean "edited the test".
