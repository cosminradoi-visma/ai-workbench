# 0-meta: how this KB works

| File | What it is |
|------|------------|
| `conventions.md` | How to write and file pages. Read before adding or reorganising. |
| `kb.yaml` | Owner, language, and the limits the health check enforces. |
| `audit.md` | Places where the KB and reality disagree, until fixed. |
| `templates/` | Work item (card, state, log, decisions), skill. |
| `scripts/` | `kb_check.py` and its Perl twin `kb_check.pl`, the health check: boot cost, links, staleness, secrets, hidden Unicode. Run it with `sh kb check` from the root. The `test-*.sh` files prove each Python script and its twin agree. |
| `decisions/` | Decisions about this KB itself, and the research behind them. |
