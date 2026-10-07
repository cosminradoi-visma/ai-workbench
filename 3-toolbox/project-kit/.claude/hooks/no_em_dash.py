#!/usr/bin/env python3
"""PostToolUse house-style hook: no em-dashes in text the agent writes.

Em-dashes are the most recognisable tell of machine-written prose. This hook checks only
the text the agent just wrote (Write content, Edit/MultiEdit new_string), never what was
already in the file, and only in prose files. If it finds one, exit code 2 sends the lines
back to the agent with an instruction to rewrite them, so the sentence gets fixed properly,
not mechanically swapped for a hyphen.

Extend BANNED with your own house style (phrases, characters). Keep it short.
"""
import json
import re
import sys

PROSE = re.compile(r"\.(md|mdx|txt|rst|adoc|html?)$", re.I)
BANNED = [
    ("—", "em-dash (—)", "use a colon, a comma, or two sentences"),
]


def written_text(tool, args):
    if tool == "Write":
        return args.get("content", "")
    if tool == "Edit":
        return args.get("new_string", "")
    if tool == "MultiEdit":
        return "\n".join(e.get("new_string", "") for e in args.get("edits", []))
    return ""


def main():
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # Windows would use cp1252
    try:
        event = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    except ValueError:
        sys.exit(0)
    if not isinstance(event, dict) or not isinstance(event.get("tool_input"), dict):
        sys.exit(0)
    args = event["tool_input"]
    path = args.get("file_path")
    if not isinstance(path, str) or not PROSE.search(path):
        sys.exit(0)
    text = written_text(event.get("tool_name", ""), args)
    problems = []
    for needle, name, fix in BANNED:
        lines = [line.strip() for line in text.splitlines() if needle in line]
        if lines:
            shown = "\n".join(f"    {line[:140]}" for line in lines[:5])
            problems.append(f"{name} in {path}, {fix}:\n{shown}")
    if problems:
        print("House style: rewrite these lines.\n" + "\n".join(problems), file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
