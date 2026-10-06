"""A fake Slack MCP server (stdio) for exercising the kit's Slack lane without Slack.

Tool names and arguments are the kit's ASSUMED connector shapes ([T] untested against the real one).
State: $FAKE_SLACK_STATE (JSON). Every write is appended to $FAKE_SLACK_SENT (JSONL). Nothing leaves this machine.
"""
import json
import os
import re

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("fake-slack", log_level="WARNING")
STATE = os.environ["FAKE_SLACK_STATE"]
SENT = os.environ["FAKE_SLACK_SENT"]
ME = os.environ.get("FAKE_SLACK_ME", "UOWNER")


def state() -> dict:
    with open(STATE) as f:
        return json.load(f)


def record(kind: str, **kw) -> None:
    with open(SENT, "a") as f:
        f.write(json.dumps({"kind": kind, **kw}) + "\n")


@mcp.tool()
def slack_search_public(query: str) -> str:
    """Search public channels. Supports in:#channel and hasmy::emoji: (messages I reacted to)."""
    s = state()
    chan = re.search(r"in:#(\S+)", query)
    mine = re.search(r"hasmy::([a-z_]+):", query)
    hits = []
    for m in s["messages"]:
        if chan and m["channel_name"] != chan.group(1):
            continue
        if mine and not any(r["name"] == mine.group(1) and ME in r["users"] for r in m.get("reactions", [])):
            continue
        hits.append({"ts": m["ts"], "channel_id": m["channel_id"], "text": m["text"],
                     "permalink": f"https://example.invalid/archives/{m['channel_id']}/p{m['ts'].replace('.', '')}"})
    return json.dumps({"messages": hits})


@mcp.tool()
def slack_read_thread(channel_id: str, message_ts: str) -> str:
    """Read a message and its thread replies."""
    msgs = [m for m in state()["messages"] if m["channel_id"] == channel_id and m["ts"] == message_ts]
    return json.dumps({"messages": msgs})


@mcp.tool()
def slack_get_reactions(channel_id: str, message_ts: str) -> str:
    """Reactions on one message, with the users who reacted."""
    for m in state()["messages"]:
        if m["channel_id"] == channel_id and m["ts"] == message_ts:
            return json.dumps({"reactions": m.get("reactions", [])})
    return json.dumps({"reactions": []})


@mcp.tool()
def slack_send_message(channel_id: str, message: str, thread_ts: str = "") -> str:
    """Send a message to a channel, optionally as a thread reply."""
    record("send", channel_id=channel_id, thread_ts=thread_ts, message=message)
    return json.dumps({"ok": True, "ts": "1759999999.000001"})


@mcp.tool()
def slack_add_reaction(channel_id: str, message_ts: str, name: str) -> str:
    """Add an emoji reaction to a message."""
    record("react", channel_id=channel_id, message_ts=message_ts, name=name)
    return json.dumps({"ok": True})


@mcp.tool()
def slack_schedule_message(channel_id: str, message: str, post_at: int) -> str:
    """Schedule a message for later."""
    record("schedule", channel_id=channel_id, message=message, post_at=post_at)
    return json.dumps({"ok": True})


if __name__ == "__main__":
    mcp.run()
