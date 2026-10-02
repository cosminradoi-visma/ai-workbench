# ADR-001: A personal workbench with a short, budgeted read path

**Date:** 2026-10-02 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** the L3→L4 workshop prep; ABQ's EACF company template (MXP-KB copy) and FACE personal template; [`research.md`](research.md)

## Context

The EACF company template is built for an organisation: owner matrices, PR approval
per layer, GitBook, Confluence and Notion adapters, five company layers. Used as it is,
`CLAUDE.md` imports a 29 KB boot file, about 7,400 tokens loaded before the first
question. Most of it covers platforms and approval flows one person never uses. The
FACE personal template is lighter but fetches its skills from a remote URL at runtime,
which adds a network dependency and a trust boundary. Colleagues at Visma need their
own context, kept safely and cheaply.

## Decision

A private, per-person workbench. Four layers (`1-me`, `2-work`, `3-toolbox`, `0-meta`)
plus a gitignored `inbox/`. The boot is under 60 lines and the read path is
`NOW.md` → one `state.md` → indexes. Procedures live in local skills that load on demand.
`kb_check.py` enforces a token budget and catches stale pages. A project kit connects any
code repo to its work item, and a personal kit sets safe defaults in `~/.claude/`.

## Why

- Context files mainly save time and tokens rather than raising correctness
  (−29% runtime and −17% output tokens in one study; no pass-rate gain in others).
  So the job is to be **short, specific and current**, not comprehensive.
- Long contexts degrade every model tested ("context rot"), and instruction-following
  decays past about 150–200 instructions. Every always-loaded line costs attention.
- The dominant failure mode of agent context is **staleness**: half of AGENTS.md files
  are never updated. A capture habit and a check that flags stale pages matter more than structure.

## Kept from EACF / FACE

The KB beats guesses · README index in every folder · ADRs with Proposed-until-ratified ·
`[unverified]` marking · the audit page · one instruction source for all tools (`AGENTS.md`) ·
the private-vs-shareable split (FACE's personal/professional domains).

## Cut, and why

| Cut | Why |
|-----|-----|
| 29 KB boot loaded every session | A 60-line router plus skills on demand |
| 16 KB setup guide | The `kb-setup` interview |
| Company layers (identity, brand, OKRs, finance, founders…) | The company maintains those. Link to them |
| Separate products / projects / departments / agents layers | One `2-work/` shape with `kind:` |
| Owner matrix, PR approval, notifications | One owner; git history is the audit trail |
| MCP/Confluence adapter, GitBook `SUMMARY.md` | Unused; `SUMMARY.md` had drifted from the real file names |
| Remote skill bundle fetched at runtime (FACE) | Supply-chain risk; skills are vendored and read before use |
| `section.page` titles and numeric file prefixes below top level | Renames and broken links whenever order changes |
| Five per-tool pointer files | Copilot, Cursor, Codex and Claude Code read `AGENTS.md` |

## Rejected

- **Keep the full template and teach people to ignore parts:** the cost is paid every session regardless.
- **A team-wide shared KB first:** the habit has to exist per person before a team KB stays current.
- **Load-everything memory bank (Cline style):** simple, but works against loading context just in time.

## Consequences

Cheaper, sharper sessions and one shape to learn. The cost is a two-minute habit at the
end of each session (`kb-capture`), and a weekly `kb-tidy`.
