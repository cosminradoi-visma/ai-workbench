# ADR-001: Store money as integer minor units

**Date:** 2026-03-14 · **Status:** Accepted · **Decided by:** example team
**Source:** issue #88, the split-refund rounding bug

## Context

Order totals were stored as floating-point numbers, and refunds of split payments
came out one cent off.

## Decision

All amounts are integers in the currency's minor unit (cents), stored with the currency
code beside them. Conversion to a display string happens only at the edge.

## Why

Integer arithmetic is exact, and every payment provider we use already speaks minor units.

## Rejected

- **Decimal type in the DB:** exact, but the JS client turns it back into a float on read.

## Consequences

Every new amount field needs a currency field. Display formatting lives in one helper.
