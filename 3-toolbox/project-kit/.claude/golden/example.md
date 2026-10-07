---
check: python3 tests/test_slugify.py
protect: tests/*
max_turns: 15
tools: Read,Edit,Write,Grep,Glob,Bash(python3 tests/*)
---

<!-- Replace with a real task: the best ones are bugs you already fixed (you know the right answer),
     small enough for one sitting, with a check that fails before and passes after.
     Start with three. Use the repo's own test command in check:.
     Run: sh .claude/golden/run.sh -->

Add a `slugify(text)` function to `src/text.py` that lowercases, replaces runs of
non-alphanumeric characters with a single hyphen and trims hyphens from both ends.
Make `tests/test_slugify.py` pass. Don't change the tests.
