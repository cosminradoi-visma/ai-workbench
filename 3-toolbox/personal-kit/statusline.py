#!/usr/bin/env python3
"""Claude Code status line: model · context used · session cost. Copy to ~/.claude/statusline.py."""
import json
import sys

try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
model = (data.get("model") or {}).get("display_name", "?")
used = (data.get("context_window") or {}).get("used_percentage")
cost = (data.get("cost") or {}).get("total_cost_usd")
parts = [model]
if used is not None:
    mark = "!" if used >= 60 else ""
    parts.append(f"ctx {used:.0f}%{mark}")
if cost is not None:
    parts.append(f"${cost:.2f}")
print(" · ".join(parts))
