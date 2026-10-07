# ADR-005: A knowledge layer that outlives tasks

**Date:** 2026-10-07 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** a review of the first version (it organised tasks, hardly any knowledge); [`research.md`](research.md), "Organising the knowledge"

## Context

The first version put everything into work items: state, log, decisions. Knowledge about systems,
people, terms and procedures had nowhere to live except a log line, so it died with the task, and
the next item started from zero. Finished items had nowhere to go either. Measured against the company
template we started from and against public agent-read KBs, the workbench had cut the *where you work*
layer without replacing it, and was about thirty lines of tooling for every line of knowledge.

## Decision

- **`4-know/`** holds what outlives tasks, one page per thing: `systems/`, `people/`, `domain/`,
  `playbooks/`, `incidents/`. Each folder has an index and a template; the Orders API example shows all
  five linked together.
- **`2-work/`** holds work: projects end and move to `_archive/` with a three-line outcome; areas never end.
- **`INDEX.md`** is the map, one line per page, opened on demand. It never loads at boot.
- **One page header** everywhere in `4-know/`: type, status, owner, updated, review cadence, data
  (verified, assumed, example), then a Purpose and a Not-here line.
- **Promote, don't bury:** `kb-capture` moves lasting facts to their page and links them; `kb-tidy`
  reviews the knowledge itself (due for review, contradictions, orphans, buried facts, duplicates).

## Why

- Stale or duplicate pages next to live ones lower accuracy (Chroma), so finished work leaves the read path.
- Every agent-read KB we looked at keeps entities (systems, people) apart from tasks, with one index.
- Diátaxis: a page serves one kind of need. A state page that is also a runbook and a glossary serves none.
- The upkeep belongs in the loop the owner already has, not in more scripts.

## Rejected

- **Bring back the company layers** (identity, strategy, policies): the company maintains those; link to them from system and concept pages.
- **Put systems and people under `1-me/`:** keeps four folders, but `1-me/` is about the owner, and mixing them blurs what loads at boot.
- **A graph database or vector search:** see `research.md`, "Not adopted".

## Consequences

The boot stays about 670 tokens: `4-know/` and `INDEX.md` load only when a task needs them. There is
one more folder to explain, and `kb-capture` asks one more question. The health check needs no change:
it already requires an index in every folder.
