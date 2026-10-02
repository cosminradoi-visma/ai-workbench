---
updated: 2026-10-02
status: verified
verified: primary sources fetched 2026-10-02 unless marked [secondary]
---

# The research behind this framework

What we read before designing the workbench, and what each source changed. Use it to
answer "why is it built like this?". Re-check before quoting numbers in a talk; the
field moves monthly.

## What actually helps agents

| Finding | Source | Changed |
|---------|--------|---------|
| Context is an attention budget: give the smallest set of high-signal tokens, load the rest just in time | [Anthropic, Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | The two-hop read path; indexes |
| Every model tested degrades as input grows, even on simple tasks | [Chroma, Context rot](https://www.trychroma.com/research/context-rot) | Line limits on first-read pages |
| Frontier models follow about 150–200 instructions reliably, then decay | [IFScale, arXiv 2507.11538](https://arxiv.org/abs/2507.11538) | 60-line boot; rules move to hooks |
| AGENTS.md cut median runtime 29% and output tokens 17%, with comparable completion | [Lulla et al., arXiv 2601.20404](https://arxiv.org/abs/2601.20404) | Value is efficiency: keep files short |
| Context files didn't raise success rates and added >20% cost; repo overviews didn't help | [Gloaguen et al., arXiv 2602.11988](https://arxiv.org/abs/2602.11988) | "Write what the agent would get wrong" rule |
| Compliance drops with session length, not file size | [arXiv 2605.10039](https://arxiv.org/abs/2605.10039) | Short sessions, `/clear`, hooks for hard rules |
| 50% of AGENTS.md files never updated; 23% of repos have stale references in AI config | [MSR 2026 study](https://usewire.io/blog/agents-md-466-projects-context-engineering/) [secondary], [arXiv 2606.09090](https://arxiv.org/html/2606.09090v1) | `kb-capture`, staleness check, link check |
| Stale specs were the main failure in a 283-session project; "repeated explanations signal documentation needs" | [Codified Context, arXiv 2602.20478](https://arxiv.org/html/2602.20478v1) | Write a skill the second time you explain something |
| Use the filesystem as memory; restorable compression (keep the path); rewrite a todo to fight drift | [Manus, Context engineering lessons](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus) | Links over copies; state snapshot |
| Raw sources → maintained wiki → schema file; ingest / query / lint; one-line index + append-only log | Karpathy's "LLM Wiki" [secondary: [AAIF summary](https://aaif.io/blog/karpathys-llm-wiki-as-agent-memory)] | `inbox/` → `kb-intake`; `log.md`; `kb_check.py` |
| Memory split: human-written instructions vs agent-written auto-memory; path-scoped rules | [Claude Code memory docs](https://code.claude.com/docs/en/memory) | "Where does this go" table; `.claude/rules/` |
| Skills: ~100 tokens of metadata until used; name must match folder; description says what + when | [Agent Skills spec](https://agentskills.io/specification), [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) | Seven local skills, short descriptions |
| ADR template and statuses | [MADR](https://adr.github.io/madr/) | Proposed → Accepted → Superseded |

## Safety

| Finding | Source | Changed |
|---------|--------|---------|
| Private data + untrusted content + a way out = exploitable, and guardrails can't fully fix it | [Willison, The lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) | The trifecta check in `safety.md` and `kb-vet` |
| Agentic top 10: goal hijack, tool misuse, supply chain, memory and context poisoning… | [OWASP Agentic Top 10 (Dec 2025)](https://genai.owasp.org/2025/12/09/owasp-top-10-for-agentic-applications-the-benchmark-for-agentic-security-in-the-age-of-autonomous-ai/), [OWASP LLM Top 10 2025](https://genai.owasp.org/llm-top-10/) | `inbox/` is untrusted; KB scanned for hidden Unicode |
| Malware ran installed AI CLIs with permission-skipping flags to steal 2,349 credentials | [Nx "s1ngularity"](https://blog.gitguardian.com/the-nx-s1ngularity-attack-inside-the-credential-leak/) | `disableBypassPermissionsMode` in the personal kit |
| A large share of public skills had flaws; malicious ones hide instructions in Unicode and rewrite memory | [CSA research note on SKILL.md poisoning](https://labs.cloudsecurityalliance.org/research/csa-research-note-skill-md-agent-context-poisoning-20260506/) [secondary] | `kb-vet`; Unicode scan |
| 5–20% of generated code references packages that don't exist, often the same names every time | [CSA note on slopsquatting](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/) [secondary] | Guard asks before installing named packages |
| Deny rules match command text only; the sandbox covers Bash only and allows `~/.ssh` reads by default | [Claude Code permissions](https://code.claude.com/docs/en/permissions), [sandboxing](https://code.claude.com/docs/en/sandboxing) | ADR-002 layers; credential denies in the strict profile |
| Transcripts are stored locally in plain text (30 days by default); feedback uploads are kept 5 years | [Claude Code data usage](https://code.claude.com/docs/en/data-usage) | `cleanupPeriodDays`, feedback off |
| MCP: per-client consent, no token passthrough, least privilege, show the full launch command | [MCP security best practices](https://modelcontextprotocol.io/specification/draft/basic/security_best_practices) | The MCP vetting checklist |
| "Never use results they do not understand, cannot explain, or that do not refer to credible sources" | [Visma, Responsible AI](https://www.visma.com/commitments/responsible-ai) | "You own what you merge" |
| AI literacy duty for deployers (Art. 4), in force since Feb 2025 | [EU AI Act Art. 4](https://www.regulation-ai.eu/en/articles/article-4/) [secondary] | The workshop itself counts as a literacy measure |

## Visma policy (internal, read 2026-10-02)

| Source | What it says | Changed |
|--------|--------------|---------|
| Visma Group "Artificial Intelligence \| Guideline" (Group Legal & Compliance, reviewed 2025-02-10) | GDPR; protect confidential info/IP; customer data only if the contract allows; check AI code for licence issues; don't use output you can't explain; accidental personal data → security@visma.com | `safety.md` rules and "if something goes wrong" |
| Visma Group IS-010 Information Classification and Handling | Public · Internal · Restricted · Customer-owned | The data-class table |
| Visma Solutions SOL-POL-002 + "Using Claude with company data" (2026-10-02) | A stricter local scheme: customer and Art. 9 data never; Restricted only with written approval; personal data one-off and minimised; no ranking/scoring/monitoring people; keep the conversation and report the same day | Worked example of a local scheme; incident steps |
| Visma Slack (#ai-tools-for-developers, 2026-05; an HR+ dev channel, 2026-09) | Org policy disables auto mode and Remote Control for some users | "Modes" note: follow company policy |

These are internal documents: cite them by name, don't copy them into public places.

## Not adopted, and why

- **Remote skill bundles** (some templates fetch their skills from a URL each session): convenient, but the instructions could change under you.
- **Load-everything memory banks** (Cline): every file every session.
- **Spec-driven toolchains** (spec-kit, BMAD): good for features, heavier than a personal KB needs. They pair well with it.
