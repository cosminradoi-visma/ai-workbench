---
name: kb-decide
description: Records a decision as an ADR in the workbench KB (the item's decisions/ folder plus index). Use when asked to "record this decision", "write an ADR", "note why we chose X", or when a real choice between alternatives was just made.
---

# kb-decide

**The KB root:** as in `kb-capture`: the current repo if it has `0-meta/kb.yaml`, else the
workbench path from `~/.claude/CLAUDE.md` (default `~/workbench`).

## Is it a decision?

Yes, if someone will ask "why is it like this?" in three months: a choice between real
alternatives with a trade-off (a library, a data shape, a boundary, a process). No for
routine work, bug fixes, or anything with one sensible option.

## Steps

1. Folder: `2-work/<item>/decisions/` (KB-wide: `0-meta/decisions/`). Next number = highest + 1.
2. Write `adr-NNN-<slug>.md` from `0-meta/templates/adr.md`:
   context, decision (followable, no code or file paths), why, rejected alternatives with
   reasons, consequences, and a **Source** line (PR, issue, doc, conversation).
3. Status **Proposed** unless the user says it's decided (then **Accepted**). If it replaces an
   older ADR, set that one to `Superseded by ADR-NNN`. Never rewrite an accepted decision.
4. Add one line to the folder's `README.md` index. Add a line to the item's `log.md`.
5. If `state.md` now contradicts the decision, fix it.

## From a design doc or PR

Pull out only the significant choices. Implementation steps and code stay in the repo; the KB
keeps the decision and the reasoning. Ask about each one rather than silently dropping it.

## Don't

- Invent a rationale the user didn't give. Ask, or mark it `[unverified]`.
