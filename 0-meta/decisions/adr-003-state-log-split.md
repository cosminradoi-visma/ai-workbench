# ADR-003: `state.md` is overwritten, `log.md` is appended

**Date:** 2026-10-02 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** experience with the Cosmo Core KB, where one roadmap page grew to 63 KB with the state section on top

## Context

A "where things stand" page is the most valuable page in a KB, until history piles up
under it and the agent has to read 60 KB to find the current state.

## Decision

Each work item has two pages. `state.md` is a snapshot, rewritten each session, capped at
80 lines. `log.md` is append-only and newest first, one line per event. Detail lives in
`notes/` or ADRs.

## Why

The read path stays two hops and a few hundred tokens, and the history is never lost.

## Rejected

- **A single page with "history below":** it works for a month, then the page stops being read.
- **No history, git only:** git shows *what* changed, not *why it mattered*.

## Consequences

`kb-capture` must do both: rewrite the state, append the log line.
