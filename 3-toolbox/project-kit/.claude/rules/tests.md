---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "tests/**"
  - "test/**"
---

<!-- Example of a path-scoped rule: it loads only when the agent reads a matching file,
     so it costs nothing in sessions that never touch tests. Edit or delete. -->

# Writing tests in this repo

- Never weaken or delete an assertion to make a test pass. If the test is wrong, say why.
- Test data is synthetic: use the builders/fixtures, never real customer or employee records.
- A bug fix comes with a test that fails without the fix.
