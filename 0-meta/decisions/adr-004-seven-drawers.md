# ADR-004: Organise everything around seven drawers, one per thing an agent needs

**Date:** 2026-10-02 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** W3 prep review: "incorporate all the things an AI needs inside the framework, so we have an organised workplace"

## Context

The KB, the project kit and the personal kit each solved a piece: memory here, guards there,
skills somewhere else. People kept asking "where does this go?", and nothing told them what
their agents were still missing.

## Decision

One model for everything: **seven drawers**. Identity, Memory, Rules, Skills, Reach, Guards,
Checks. Each says what the agent needs to know and where it lives. Around them sit the loop
(capture, tidy), which keeps them true, and the toolbox, the shareable part. `kb_check.py --report`
scores a workbench out of seven and names the next step for each empty drawer. Drawer 7 got real
tools: golden tasks with a runner, and a fresh-eyes reviewer agent.

## Why

A model people can count on their fingers beats a table of file paths. It also turns the vague
"is my setup good?" into a score with a next step. And it makes Checks a first-class drawer: the
W2 room's third-biggest ask was "measuring whether agent output is actually good".

## Rejected

- **Layers only (`1-me`, `2-work`, `3-toolbox`):** they say where files are, not what the agent needs.
- **More drawers (output styles, statusline, models…):** settings, not needs. Seven is already a lot to remember.

## Consequences

New features have to name their drawer. The report only sees repos named on a work-item card
(`- Repo: \`path\``), so `kb-link-repo` must write that line.
