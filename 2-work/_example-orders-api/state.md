---
updated: 2026-10-02
verified: git log on main, the test run, the prod flag dashboard
---

# Orders API — where it stands

## Right now

- v1.4 in production. Order creation and status endpoints are stable.
- Refund endpoint is behind the `refunds` flag, on in test only.

## Next

1. Finish the refund idempotency key (#212), then switch the flag on in prod.
2. Decide whether `OrderRepository` moves from hand-written SQL to the query builder (record it with `kb-decide`).

## Waiting on

- Prod flag switch needs sign-off from fulfilment (Ana), asked 2026-09-28.

## How to work on it

- Run: `docker compose up -d && npm run dev` · Test: `npm test`, `npm run test:int` (needs the compose DB)
- Proof a change works: `npm run test:int` against the compose DB. Unit tests mock the DB and miss SQL bugs.

## Gotchas

- Integration tests time out if the compose DB isn't `healthy` yet. Wait for it.
- `npm run db:reset` uses whatever `.env.test` points at. Check it says localhost.

## Deliberately not done

- No ORM. Decided against in 2026-02; the hand-written SQL is the point, not an oversight.
- Money is never a float (ADR-001).
