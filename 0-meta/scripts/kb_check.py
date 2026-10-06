#!/usr/bin/env python3
"""Workbench health check. Standard library only, Python 3.9+.

    python3 0-meta/scripts/kb_check.py           full report
    python3 0-meta/scripts/kb_check.py --brief   problems only, max 8 lines (the session-start hook)
    python3 0-meta/scripts/kb_check.py --report  the seven drawers: what your agents have, and what is missing

Checks
  boot      tokens loaded before your first message (this KB, and ~/.claude/CLAUDE.md everywhere)
  indexes   every folder has a README.md that lists every file in it
  links     relative markdown links point at files that exist
  fresh     NOW.md and each state.md are dated, recent and within their line limits
  skills    name matches its folder; description present and short enough to stay in the listing
  safety    likely secrets (error) and hidden Unicode used to smuggle instructions (error)
  setup     TODO left in kb.yaml, unfilled placeholders

Exit code 1 if there are errors, so it can gate a commit or a CI job.
"""
import datetime as dt
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
HOME = pathlib.Path.home()
NO_INDEX = {"templates", "scripts", "inbox", "notes", "slack-bot"}  # folders that don't need a README index (slack-bot: code, not KB pages)
TEXT_EXT = {".md", ".yaml", ".yml", ".json", ".py", ".sh", ".toml", ".txt", ".example", ".mdc"}
SECRETS = [
    (r"AKIA[0-9A-Z]{16}", "AWS access key"),
    (r"gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}", "GitHub token"),
    (r"sk-(ant-)?[A-Za-z0-9_-]{20,}", "API key"),
    (r"xox[abprs]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key"),
    (r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}", "JWT"),
    (r"(?i)\b(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*['\"]?[^\s'\"<>{}$]{8,}", "credential assignment"),
    (r"(?i)(postgres(ql)?|mysql|mongodb(\+srv)?|sqlserver|redis|amqp)://[^\s:/@]+:[^\s@]+@", "connection string with password"),
]
HIDDEN = re.compile("[\u200b-\u200f\u202a-\u202e\u2060-\u2064\ufeff\U000e0000-\U000e007f]")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s#]+)(#[^)]*)?\)")


def read(p):
    return p.read_text(encoding="utf-8", errors="ignore")


def tokens(text):
    # ~4 characters per token: the usual rule of thumb for English prose and markdown.
    # HTML comments are stripped by Claude Code before loading, so they don't count.
    return round(len(re.sub(r"<!--.*?-->", "", text, flags=re.S)) / 4)


def rel(p):
    try:
        return str(p.relative_to(ROOT))
    except ValueError:
        return "~/" + str(p.relative_to(HOME)) if str(p).startswith(str(HOME)) else str(p)


def config():
    cfg = {"boot_budget_tokens": 2000, "now_max_lines": 40, "state_max_lines": 80,
           "stale_days": 14, "skill_description_max": 300}
    path = ROOT / "0-meta" / "kb.yaml"
    if path.exists():
        for line in read(path).splitlines():
            m = re.match(r"^(\w+):\s*([^#]*)", line)
            if m:
                val = m.group(2).strip()
                cfg[m.group(1)] = int(val) if val.isdigit() else val
    return cfg


def imports(entry, seen=None, depth=0):
    """A CLAUDE.md plus everything it pulls in with @path (Claude Code follows up to 4 hops)."""
    seen = seen if seen is not None else []
    if depth > 4 or not entry.is_file() or entry in seen:
        return seen
    seen.append(entry)
    text = re.sub(r"```.*?```", "", read(entry), flags=re.S)
    for m in re.finditer(r"(?m)^@(\S+)", text):
        ref = m.group(1)
        target = pathlib.Path(ref).expanduser() if ref.startswith("~") else entry.parent / ref
        imports(target.resolve(), seen, depth + 1)
    return seen


def tracked_files():
    for p in ROOT.rglob("*"):
        r = p.relative_to(ROOT)
        if p.is_file() and ".git" not in r.parts and "node_modules" not in r.parts and "__pycache__" not in r.parts:
            yield p


def fresh(page, days):
    m = page.exists() and re.search(r"(?m)^updated:\s*(\d{4}-\d{2}-\d{2})", read(page))
    return bool(m) and (dt.date.today() - dt.date.fromisoformat(m.group(1))).days <= days


def linked_repos():
    """Repo paths named in work-item cards ('- Repo: `path`'), that exist on this machine."""
    repos = []
    for card in sorted((ROOT / "2-work").glob("*/README.md")):
        if card.parent.name.startswith("_"):
            continue
        m = re.search(r"(?m)^- Repo:\s*`?([^`\s]+)`?", read(card))
        if m:
            path = pathlib.Path(m.group(1)).expanduser()
            if path.is_dir():
                repos.append(path)
    return repos


def report(cfg):
    """The seven drawers: what an agent needs, and whether yours has it yet."""
    days = int(cfg["stale_days"])
    repos = linked_repos()
    user = HOME / ".claude"
    rows = []

    profile = ROOT / "1-me" / "profile.md"
    filled = [l for l in read(profile).splitlines() if l.startswith("- ") and "<!--" not in l] if profile.exists() else []
    rows.append(("Identity", len(filled) >= 3, f"profile.md: {len(filled)} lines filled in", "/kb-setup"))

    items = [p for p in (ROOT / "2-work").glob("*/state.md") if not p.parent.name.startswith("_")]
    current = [p for p in items if fresh(p, days)]
    ok = fresh(ROOT / "NOW.md", days) and bool(current)
    rows.append(("Memory", ok, f"NOW.md {'current' if fresh(ROOT / 'NOW.md', days) else 'stale or undated'} · {len(current)}/{len(items)} items current", "kb-capture"))

    ruled = [r for r in repos if (r / "AGENTS.md").exists() or (r / "CLAUDE.md").exists()]
    rows.append(("Rules", bool(ruled), f"{len(ruled)} linked repo(s) with AGENTS.md", "/kb-link-repo"))

    own = {p.parent.name for base in [user / "skills", *[r / ".claude" / "skills" for r in repos]]
           for p in base.glob("*/SKILL.md") if not p.parent.name.startswith("kb-")}
    rows.append(("Skills", bool(own), f"{len(own)} of your own (plus the kb-* skills)", "0-meta/templates/skill/"))

    mcp = ROOT / "3-toolbox" / "mcp.md"
    reg = [l for l in read(mcp).split("## Register")[-1].split("##")[0].splitlines()
           if l.startswith("| ") and "<!--" not in l and not l.startswith("| Server") and "---" not in l] if mcp.exists() else []
    wired = [r for r in repos if (r / ".mcp.json").exists()]
    rows.append(("Reach", bool(reg or wired), f"{len(reg)} server(s) in mcp.md · {len(wired)} repo(s) with .mcp.json", "3-toolbox/mcp.md"))

    settings = user / "settings.json"
    personal = settings.exists() and "disableBypassPermissionsMode" in read(settings)
    guarded = [r for r in repos if (r / ".claude" / "hooks" / "guard.py").exists()]
    rows.append(("Guards", personal and bool(guarded), f"personal kit {'on' if personal else 'off'} · {len(guarded)} repo(s) guarded", "/kb-link-repo + personal kit"))

    golden = [p for r in repos for p in (r / ".claude" / "golden").glob("*.md") if p.stem not in ("README", "example")]
    reviewer = [r for r in repos if (r / ".claude" / "agents" / "reviewer.md").exists()]
    rows.append(("Checks", bool(golden or reviewer), f"{len(golden)} golden task(s) · reviewer in {len(reviewer)} repo(s)", ".claude/golden/ + reviewer agent"))

    score = sum(ok for _, ok, _, _ in rows)
    print(f"Your workbench: {score}/7 drawers\n")
    for n, (name, ok, detail, fix) in enumerate(rows, 1):
        hint = "" if ok else f"  → {fix}"
        print(f"  {'✓' if ok else '·'} {n} {name:<9} {detail}{hint}")
    if not repos:
        print("\n  No linked repo found yet: add '- Repo: `path`' to a work item card, or run /kb-link-repo.")
    return 0


def main():
    if "--report" in sys.argv:
        return report(config())
    brief = "--brief" in sys.argv
    cfg = config()
    errors, warnings, info = [], [], []
    files = list(tracked_files())

    # boot
    boot = imports(ROOT / "CLAUDE.md") or [ROOT / "AGENTS.md"]
    profile = ROOT / "1-me" / "profile.md"
    if profile.exists() and profile not in boot:
        boot.append(profile)  # AGENTS.md tells every session to read it
    cost = sum(tokens(read(f)) for f in boot)
    budget = int(cfg["boot_budget_tokens"])
    line = f"Boot cost ~{cost} tokens (budget {budget}): " + ", ".join(f"{rel(f)} ~{tokens(read(f))}" for f in boot)
    (warnings if cost > budget else info).append(line)
    user_md = HOME / ".claude" / "CLAUDE.md"
    if user_md.exists():
        g = imports(user_md)
        gcost = sum(tokens(read(f)) for f in g)
        msg = f"Global boot (every repo, from ~/.claude/CLAUDE.md) ~{gcost} tokens"
        (warnings if gcost > budget else info).append(msg + ("; trim it, it loads everywhere" if gcost > budget else ""))

    # indexes
    for d in sorted({p.parent for p in files} | {p for p in ROOT.rglob("*") if p.is_dir()}):
        r = d.relative_to(ROOT)
        if d == ROOT or any(part.startswith(".") or part in NO_INDEX or part in ("node_modules", "__pycache__") for part in r.parts):
            continue
        readme = d / "README.md"
        if not readme.exists():
            warnings.append(f"{r}/ has no README.md index")
            continue
        text = read(readme)
        for child in sorted(d.iterdir()):
            if child.name in ("README.md", "__pycache__") or child.name.startswith("."):
                continue
            if child.name not in text and child.stem not in text:
                warnings.append(f"{r}/README.md doesn't list {child.name}")

    # links
    for p in files:
        if p.suffix != ".md" or "templates" in p.relative_to(ROOT).parts:
            continue
        for m in LINK.finditer(re.sub(r"```.*?```|`[^`]*`|<!--.*?-->", "", read(p), flags=re.S)):
            target = m.group(1)
            if re.match(r"^[a-z]+:", target) or target.startswith("/"):
                continue
            if not (p.parent / target).exists():
                warnings.append(f"{rel(p)} links to missing {target}")

    # fresh
    today, stale = dt.date.today(), int(cfg["stale_days"])
    pages = [(ROOT / "NOW.md", int(cfg["now_max_lines"]))]
    pages += [(p, int(cfg["state_max_lines"])) for p in sorted((ROOT / "2-work").glob("*/state.md"))]
    for page, limit in pages:
        if not page.exists():
            continue
        text = read(page)
        n = len(text.splitlines())
        if n > limit:
            warnings.append(f"{rel(page)} is {n} lines (limit {limit}): move history to log.md, detail to notes/")
        m = re.search(r"(?m)^updated:\s*(\d{4}-\d{2}-\d{2})", text)
        if not m:
            warnings.append(f"{rel(page)} has no 'updated: YYYY-MM-DD' (run kb-setup or kb-capture)")
        elif (today - dt.date.fromisoformat(m.group(1))).days > stale:
            warnings.append(f"{rel(page)} last updated {m.group(1)}: still true? (kb-capture)")

    # skills
    for skill in sorted(ROOT.glob(".claude/skills/*/SKILL.md")):
        parts = read(skill).split("---")
        meta = parts[1] if len(parts) > 2 else ""
        name = re.search(r"(?m)^name:\s*(\S+)", meta)
        desc = re.search(r"(?m)^description:\s*(.+)$", meta)
        if not name or name.group(1) != skill.parent.name:
            warnings.append(f"{rel(skill)}: 'name' must match the folder name '{skill.parent.name}'")
        if not desc:
            warnings.append(f"{rel(skill)}: no description, so it will never trigger")
        elif len(desc.group(1)) > int(cfg["skill_description_max"]):
            warnings.append(f"{rel(skill)}: description is {len(desc.group(1))} chars (max {cfg['skill_description_max']})")

    # safety
    me = pathlib.Path(__file__).resolve()
    guards = {"prompt_guard.py", "guard.py"}
    for p in files:
        if p.suffix not in TEXT_EXT and p.name not in {".env", ".mcp.json"}:
            continue
        r = p.relative_to(ROOT)
        bucket = warnings if r.parts[0] == "inbox" else errors
        for n, text in enumerate(read(p).splitlines(), 1):
            if HIDDEN.search(text):
                bucket.append(f"{r}:{n} contains hidden Unicode (can smuggle instructions to an agent)")
            if p.resolve() == me or p.name in guards:
                continue
            for pattern, label in SECRETS:
                if re.search(pattern, text):
                    bucket.append(f"{r}:{n} looks like a {label}")

    # setup
    if "TODO" in read(ROOT / "0-meta" / "kb.yaml"):
        info.append("Setup not finished: 0-meta/kb.yaml has TODO. Run /kb-setup.")
    holes = sum(read(p).count("<!-- ") for p in files if p.suffix == ".md"
                and p.relative_to(ROOT).parts[0] in ("1-me", "2-work") and "_example" not in str(p))
    if holes:
        info.append(f"{holes} unfilled placeholders in 1-me/ and 2-work/")

    if brief:
        problems = [f"ERROR {e}" for e in errors] + [f"warn  {w}" for w in warnings]
        if problems:
            print("Workbench check (run kb-tidy to fix):")
            for line in problems[:8]:
                print("  " + line)
            if len(problems) > 8:
                print(f"  … and {len(problems) - 8} more")
    else:
        for label, items in (("ERRORS", errors), ("WARNINGS", warnings), ("INFO", info)):
            if items:
                print(f"{label} ({len(items)})")
                for line in items:
                    print("  " + line)
        if not errors and not warnings:
            print("OK: no problems found.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
