---
type: incident
status: closed
owner: example
updated: 2026-03-14
review: at-change
data: example
---

# 2026-03: split refunds came out one cent off (example)

**Purpose:** what this taught, so nobody has to learn it twice.
**Not here:** blame.

**Fictional: shows a good incident page. Delete it once you have your own.**

- **Impact:** about 40 customers refunded one cent short over two weeks; found by support.
- **Systems:** [Orders API](../systems/_example-orders-api.md)

## What happened

Refunds split across two payments were computed in floating point and rounded per part.
The parts summed to one cent less than the original amount.

## Why

Amounts were stored as floats, so the arithmetic was never exact.

## What changed

- All amounts became integer minor units: [ADR-001](../../2-work/_example-orders-api/decisions/adr-001-money-as-integer-cents.md), [the concept page](../domain/_example-minor-units.md).
- A test that refunds an odd amount in two parts and checks the sum.
