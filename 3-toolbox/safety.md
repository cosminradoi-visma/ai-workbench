---
updated: 2026-10-02
status: assumed
verified: Claude Code docs and public sources, 2026-10-02. Your company's own AI policy and data classification win wherever they differ.
---

# Safety

What keeps you, your company and your customers safe when an agent works for you.
Short version first; the reasons follow.

## The six rules

1. **Restricted data never goes to a model.** Secrets, customer records, payroll and HR data,
   personal data, security findings. Use synthetic data in prompts, fixtures and examples.
2. **Company accounts and approved tools only.** Never a personal subscription for company code.
   Consumer plans can train on your data and keep it for years.
3. **You own what you merge.** Read every diff. If you can't explain it, don't ship it.
   Visma's own commitment: never use results you *"do not understand, cannot explain,
   or that do not refer to credible sources"* ([Visma Responsible AI](https://www.visma.com/commitments/responsible-ai)).
4. **Read before you install.** Skills, plugins, hooks and MCP servers run with your
   permissions. Run `kb-vet` first.
5. **Break the trifecta.** Never let one session combine private data, untrusted content
   and a way to send data out (below).
6. **Rules that must hold go in settings and hooks, not in prompts.** A prompt is advice;
   a deny rule is a wall.

## What may go to a model

A suggested scheme. **Check your company's actual classification and AI policy, and
ask Security when in doubt.**

| Class | Examples | To an approved company tool? |
|-------|----------|------------------------------|
| Public | Open-source code, public docs | Yes |
| Internal | Internal docs, non-sensitive code, architecture notes | Yes |
| Confidential | Proprietary source code, unreleased plans, internal designs | Yes, on the approved enterprise tenant only, with no unapproved MCP servers |
| Restricted | Credentials, personal data, customer and payroll records, production data, open vulnerabilities | **No**, unless your DPO and Security have approved a specific path |

Under GDPR, putting personal data in a prompt is processing: it needs a lawful basis,
a processor agreement and data minimisation. Synthetic data needs none of that.

## The lethal trifecta

An agent is exploitable when one session has all three:

| Private data | + Untrusted content | + A way out |
|--------------|---------------------|-------------|
| Your repo, DB, mailbox, KB | Issues, PRs, READMEs, web pages, tickets, MCP results, `inbox/` | `curl`, web fetch, `git push`, an MCP tool that writes or sends |

Text the agent reads can carry instructions, and models follow them. Nobody has a
reliable filter for that ([Willison](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)). Remove one leg:

- Reading tickets or web pages? Keep write and send tools off in that session.
- Need to push or post? Don't feed it untrusted text in the same session.
- Connecting a new MCP server? Ask which leg it adds (`kb-vet` does).

## The layers, and what each misses

| Layer | Stops | Misses |
|-------|-------|--------|
| **Permissions** `deny` / `ask` | Tool calls matching a pattern (`Read(./.env)`, `Bash(git push *)`) | Rewritten commands (`git -C . push`); `Read` denies don't stop `grep -r` from Bash |
| **Sandbox** (strict profile) | Bash touching files or hosts outside the allowlist | Only covers Bash; allows `~/.ssh` reads unless you deny them; can't inspect TLS traffic |
| **Hooks** (guard scripts) | Anything you can detect in the call or the prompt | Only what you thought to check |
| **You**, reading the diff | Everything that matters | Only what you actually read |

Deny rules are a speed bump. The sandbox is the wall. Review is the gate that counts.

## Modes

| Mode | Use |
|------|-----|
| `plan` | Unfamiliar code, large changes: the agent reads and proposes, changes nothing |
| `default` / `acceptEdits` | Everyday work |
| `auto` | Classifier-approved actions. Check that your company policy allows it |
| `bypassPermissions` | **Only** inside a disposable devcontainer with no secrets. The personal kit disables it |

## Supply chain

- **Skills and plugins:** read every file, including scripts and hook definitions. Look for
  hidden Unicode, network calls, base64 blobs, and writes to memory or settings. Pin a version.
- **MCP servers:** first-party or internal publisher, pinned version, read-only first, full
  launch command read, no `npx` of an unpinned package. Re-check after updates, because tool
  descriptions can change after you approved them.
- **Packages the agent suggests:** check they exist, are the one you meant, and aren't brand new.
  Models invent plausible package names, and attackers register them.
- **Cloned repos:** a repo's `.claude/settings.json`, hooks and `.mcp.json` are code. Read them
  before trusting the folder. For headless runs on untrusted repos use `claude -p --bare`.

## Where your data ends up

- Transcripts sit in plain text under `~/.claude/projects/` (30 days by default). Anything the agent
  read is in them. The personal kit sets `cleanupPeriodDays: 14`. Never commit or sync that folder.
- `/feedback` and bug reports upload the conversation, which is kept for years. The personal kit
  turns the command off.
- Commercial plans (Team, Enterprise, API) don't train on your data unless your org opts in.

## If something leaks

1. **Rotate the secret now.** Deleting the commit doesn't help: it's in history, caches and transcripts.
2. Tell your security contact (`1-me/team.md`), even if it was "only a test key".
3. Add a line to `1-me/learnings.md` and a check to the guard hook so it can't happen twice.

## Why this matters beyond your repo

The EU AI Act requires deployers to support AI literacy among staff (Art. 4, since Feb 2025).
Knowing these rules, and writing them down where your agents read them, is part of that.
