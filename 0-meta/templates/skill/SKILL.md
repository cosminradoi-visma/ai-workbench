---
name: my-skill
description: Drafts release notes from merged PRs. Use when asked for release notes, a changelog, or "what shipped".
---

<!-- `name` must match the folder name: lowercase letters, digits, hyphens.
     The description is ALWAYS loaded (it decides whether the skill is ever used):
     third person, what it does + when to use it, trigger words first, under ~250 characters.
     Everything below loads only when the skill runs, so detail is cheap here.
     Optional Claude Code fields: disable-model-invocation: true (only runs when you type
     /my-skill, which suits anything with side effects), allowed-tools, paths, context: fork.
     Portable across tools: name, description, license, compatibility, metadata, allowed-tools. -->

# My skill

## When to use it

- <!-- trigger -->

## Steps

1. <!-- step. Prefer a script in scripts/ for anything deterministic: it runs, it isn't read. -->

## Done when

- <!-- a check the agent can actually run -->

## Don't

- <!-- the failure you have seen -->
