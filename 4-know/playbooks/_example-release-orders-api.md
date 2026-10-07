---
type: playbook
status: active
owner: example
updated: 2026-09-15
review: at-change
data: example
---

# Release the Orders API: playbook (example)

**Purpose:** the exact steps to ship a new orders-api version, and how you know it worked.
**Not here:** why releases need sign-off → [Ana's page](../people/_example-ana.md).

**Fictional: shows a good playbook. Delete it once you have your own.**

**When:** a release tag is agreed · **Takes:** 20 minutes · **Needs:** deploy rights on the prod cluster

## Steps

1. `npm test && npm run test:int` on the release commit, against the compose DB.
2. Tag it: `git tag v1.x.y && git push origin v1.x.y`. CI builds and deploys to test.
3. Check the test dashboard: new version live, error rate flat for 10 minutes.
4. Promote to prod from the pipeline. Post the version and the changelog in the team channel.

## Done when

- `GET /health` in prod reports the new version, and the order-created rate is flat for 15 minutes.

## If it goes wrong

- Error rate up: roll back from the pipeline (previous tag), then open an incident page.
