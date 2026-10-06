# ADR-002: Safety comes from settings, sandbox and hooks; prose only explains

**Date:** 2026-10-02 · **Status:** Proposed · **Decided by:** Cosmin Radoi
**Source:** [`research.md`](research.md) §Safety; Visma Responsible AI commitments

## Context

Instructions in `CLAUDE.md` are advisory: the model usually follows them, and nothing
guarantees it. Visma handles payroll, HR and accounting data under GDPR. Agents read
untrusted content all the time (issues, READMEs, web pages, MCP results) and can be
redirected by it. Malware has already used installed AI CLIs in "skip permissions" mode
to hunt for credentials (the Nx npm compromise, Aug 2025).

## Decision

Must-hold rules are enforced in layers that don't depend on the model agreeing:

1. **Permissions** (`deny` / `ask`): no secret files, ask before push and agent-config edits,
   bypass mode disabled.
2. **Sandbox** (optional strict profile): the real boundary for Bash. Deny rules only match command text.
3. **Hooks:** a `PreToolUse` guard and a `UserPromptSubmit` guard that stop secrets and
   real IBANs and CNPs at the door.
4. **Review:** a human reads every diff before it merges. You own what you merge.

Prose in `safety.md` explains *why*, so people make good calls where no rule reaches.

## Why

Each layer catches what the others miss, and none of them costs context tokens.

## Rejected

- **A long "never do X" list in CLAUDE.md:** advisory, costly, and decays with session length.
- **Blocking all network and installs by default:** safe, but people would turn it off on day one.
  `ask` is the default; the sandbox is opt-in.

## Consequences

Some friction: prompts on push, on installs, on edits to agent config. That friction is
the point. The guard lists are short on purpose, so everyone can read and extend them.
