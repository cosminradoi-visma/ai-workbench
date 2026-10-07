---
type: system
status: active        # draft | active | archived
owner: <!-- who keeps this page true: you, usually -->
updated: YYYY-MM-DD
review: quarterly     # monthly | quarterly | at-change: when kb-tidy asks "still true?"
data: assumed         # verified (checked against the source) | assumed | example
---

# <System name>

**Purpose:** what an agent needs to know before touching or talking about <system>.
**Not here:** how the code works (it can read the code) · current work on it → `2-work/<item>/state.md`

<!-- One sentence: what it does and for whom. -->

## Owners and contacts

- Owning team: <!-- --> · People: <!-- link 4-know/people/ pages -->
- Where to ask / where incidents go: <!-- channel -->

## Depends on · used by

- Depends on: <!-- system pages, external APIs, queues -->
- Used by: <!-- who breaks when this breaks -->

## Environments

| Env | Where | Notes |
|-----|-------|-------|
| <!-- test / prod --> | <!-- URL or name, no secrets --> | <!-- e.g. shared DB: never reset --> |

## Traps

- <!-- what cost someone an hour: "when X, do Y" -->

## Decisions and incidents

- <!-- links to ADRs in 2-work/<item>/decisions/ and pages in 4-know/incidents/ -->
