---
type: concept
status: active
owner: example
updated: 2026-03-14
review: at-change
data: example
---

# Money is an integer count of the currency's smallest unit (example)

**Purpose:** what "amount" means in our services, so an agent never writes a float.
**Not here:** display formatting rules → the shared formatting helper's README.

**Fictional: shows a good concept page. Delete it once you have your own.**

Every amount is an integer in the currency's minor unit (cents for EUR), stored next to its
ISO currency code. Converting to a display string happens once, at the edge.

## Rules

- `amount_minor` + `currency` travel together, always.
- Not every currency has two decimals (JPY has none): never hard-code `/ 100`.

## The common mistake

- Parsing `"12.30"` into a float "just for the comparison". Compare minor units instead.

## See also

- [ADR-001](../../2-work/_example-orders-api/decisions/adr-001-money-as-integer-cents.md) · [the incident that caused it](../incidents/_example-2026-03-split-refund-rounding.md)
