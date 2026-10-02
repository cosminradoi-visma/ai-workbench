---
updated: 2026-10-02
status: verified
verified: Claude Code docs; Visma Group AI Guideline and IS-010 class names; Visma Solutions' Claude guide (2026-10-02) as the worked example. Your company's own policy wins wherever it differs.
---

# Safety

What keeps you, your company and your customers safe when an agent works for you.
Short version first; the reasons follow.

## The six rules

1. **Customer data and sensitive personal data never go to a model.** Nor do secrets, or Restricted
   information without written approval. Use synthetic data in prompts, fixtures and examples.
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

## What may go to a model (Visma)

Visma Group classifies information in four classes (**IS-010 Information Classification and
Handling**): Public · Internal · Restricted · Customer-owned. Your company may implement it
with a **stricter local scheme**. Visma Solutions, for example, splits it into ten codes and
publishes a "Using Claude with company data" guide. **Find your company's version and follow
it; it wins over this table.** Ask your security/privacy team when in doubt, and apply the stricter class.

| Group class | Examples | Into Claude on your company account? |
|-------------|----------|---------------------------------------|
| Public | Open-source code, public docs, press releases | Yes |
| Internal | Internal docs, guidelines, most source code and designs, meeting notes | Yes, minimised: only what the task needs |
| Restricted | M&A, restructuring, unreleased financials, security findings (in some schemes) | **No**, unless you hold prior written approval |
| Customer-owned | Anything customers hold in our products: payroll, accounting, HR records, support extracts | **Never.** There is nothing to apply for |
| Personal data | Colleagues, contacts, candidates | Only one-off and minimised (roles, not names). Recurring or automated use needs your DPM |
| Sensitive personal data | Health, sick leave, union membership (GDPR Art. 9) | **Never** |

And from the **Visma Group AI Guideline** (Group Legal & Compliance):

- **Never use output you don't understand** or can't explain.
- **AI-generated code:** check it isn't copied from licensed public code (search GitHub; the more
  specialised the code, the higher the risk), run your licence-compliance scans, and follow your
  company's approval for AI-generated code in products.
- **Customer data only if the customer contract allows it.**
- **Never use an AI tool to rank, score, profile or monitor people.** A human makes decisions about people.
- **Company account only.** Personal Claude Pro or Max accounts are not approved for company data.

Under GDPR, personal data in a prompt is processing, and the data leaves the EU/EEA. Synthetic data avoids both problems.

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
| `auto` | Classifier-approved actions. Some Visma organisations disable it in managed settings; follow your company's policy |
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

## If something goes wrong

**A secret leaked** (token, key, password):
1. **Rotate it now.** Deleting the commit doesn't help: it's in history, caches and transcripts.
2. Tell your security contact (`1-me/team.md`), even if it was "only a test key".

**Banned data went into the model** (customer data, a payroll extract, a sick-leave note):
1. **Stop using that conversation, and don't delete it.** Your DPM needs it to see what was exposed.
   In Claude Code the conversation is the local transcript under `~/.claude/projects/`. Copy it aside before the cleanup period removes it.
2. **Report it the same working day** to your DPM or security team. Accidental personal data goes to **security@visma.com**.
   Reporting fast is expected behaviour. Not reporting is the problem.

Afterwards: add a line to `1-me/learnings.md` and a check to the guard hook so it can't happen twice.

## Why this matters beyond your repo

The EU AI Act requires deployers to support AI literacy among staff (Art. 4, since Feb 2025).
Knowing these rules, and writing them down where your agents read them, is part of that.
