# 4-know: what you know (private)

The knowledge that outlives any one task: the systems around you, the people, the domain, how
things are done, and what went wrong. A work item in `2-work/` finishes. What you learned there
moves here, so the next item starts from it.

| Folder | One page per | Answers | Template |
|--------|--------------|---------|----------|
| `systems/` | service, app, database, pipeline you touch | what is it, who owns it, what it depends on, its traps | `0-meta/templates/system.md` |
| `people/` | person you work with (work facts only) | what they own, what they care about, how to ask them | `0-meta/templates/person.md` |
| `domain/` | business or technical concept | what it means *here*, the rules, the common mistake | `0-meta/templates/concept.md` |
| `playbooks/` | task you repeat: release, rotate a secret, onboard | the exact steps, and how you know it worked | `0-meta/templates/playbook.md` |
| `incidents/` | thing that broke | what happened, why, what changed so it won't again | `0-meta/templates/incident.md` |

Each folder's `README.md` is its index: one line per page. `INDEX.md` at the root lists them all.

## How a page gets here

- **Promoted, not written from scratch.** When `kb-capture` finds a fact that will matter after this
  task (a system's gotcha, who owns what, why a rule exists), it goes to its page here, and the
  work item links to it. Ask for it: "promote that to the payments system page".
- **One page per thing, named by the thing:** `systems/payments-api.md`, `domain/minor-units.md`,
  `people/ana-pop.md`. A concept page's first line states the claim, not the topic.
- **Link, don't copy.** A work item says "see `4-know/systems/payments-api.md`"; it doesn't repeat it.

## What doesn't belong

Personal details about people (only their work: role, ownership, how to reach them), customer data,
secrets. Anything the company already documents well: link to it instead.
