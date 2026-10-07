---
name: interview
description: Interviews the owner one question at a time until a task is clear enough to build without asking again, then writes the spec into the work item. Use when asked to "interview me", "grill me", "help me think this through", "spec this", or when a new task is vague.
---

# interview

The trick, from Anthropic's Claude Code team: instead of writing a long prompt, let the agent ask.
People answer questions far better than they write specs.

## Steps

1. **Read before asking.** `NOW.md`, the item's `2-work/<item>/state.md` (create the item from
   `0-meta/templates/work-item/` if it is new), and the `4-know/` pages it links. Never ask what a page
   already answers: say "4-know/systems/payments-api.md says X. Still true?" instead.
2. **One question at a time.** Use the AskUserQuestion tool when you have it; otherwise a numbered question
   with two to four suggested answers and "something else". Short questions, no preamble.
3. **Cover what usually goes wrong:** what "done" looks like and how we will know (the test or check),
   who uses it, constraints, edge cases, what is out of scope, risks, who has to agree, what must not change.
4. **Stop when you could build it without asking anything else.** Say "I have enough." The owner can say
   "enough" earlier; then list what is still open.
5. **Write it down:** the spec as "Next" and "How we'll know it works" in `state.md`; each real choice, with
   its reason, through `kb-decide`; open questions under "Waiting on". Facts that will outlive the task
   (a system's trap, who signs off) go to their `4-know/` page.
6. Suggest building it in a **fresh session** (`/clear`): the spec is on disk now, so the new session starts
   clean and focused.

## Don't

- Ask more than one question per message.
- Start building during the interview.
- Write customer data or anyone's personal details into the spec.
