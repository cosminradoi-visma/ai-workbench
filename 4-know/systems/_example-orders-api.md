---
type: system
status: active
owner: example
updated: 2026-10-02
review: quarterly
data: example
---

# Orders API (example)

**Purpose:** what an agent needs to know before touching or talking about the Orders API.
**Not here:** how the code works · current work → [`2-work/_example-orders-api/state.md`](../../2-work/_example-orders-api/state.md)

**Fictional: shows a good system page. Delete it once you have your own.**

Takes orders from the web shop and hands them to fulfilment. REST, Node, Postgres.

## Owners and contacts

- Owning team: example team · Prod sign-off: [Ana](../people/_example-ana.md) (fulfilment)
- Questions: the team channel · Incidents: the on-call rota

## Depends on · used by

- Depends on: Postgres (own DB), the payment provider's refunds API
- Used by: the web shop checkout, fulfilment's picking app (webhooks since v1.4)

## Environments

| Env | Where | Notes |
|-----|-------|-------|
| local | `docker compose up -d` | integration tests need the compose DB `healthy` first |
| test | the shared test cluster | `refunds` flag on |
| prod | the prod cluster | `refunds` flag off until Ana signs off |

## Traps

- Amounts are integer minor units, never floats: see [minor units](../domain/_example-minor-units.md).
- `npm run db:reset` resets whatever `.env.test` points at. Check it says localhost.

## Decisions and incidents

- [ADR-001: money as integer cents](../../2-work/_example-orders-api/decisions/adr-001-money-as-integer-cents.md)
- [2026-03: split refunds one cent off](../incidents/_example-2026-03-split-refund-rounding.md)
- Release: [playbook](../playbooks/_example-release-orders-api.md)
