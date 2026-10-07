# Personal kit

Safe defaults for `~/.claude/`, the settings that apply to you in every repo.
`kb-setup` offers to install them: it **merges** into what you already have, shows the
diff, and asks first. To do it by hand, copy the pieces you want.

| File | Goes to | Does |
|------|---------|------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` (merge) | Loads your profile everywhere, and tells agents where your workbench is |
| `settings.json` | `~/.claude/settings.json` (merge) | Disables bypass mode; denies reads of cloud credentials, SSH keys and `.env`; asks before push; keeps transcripts 14 days; turns off feedback uploads; adds the status line |
| `settings.strict.json` | merge too, if you want the wall | Sandbox for Bash: package registries only on the network, no reads of credential folders. Linux/WSL needs `bubblewrap` and `socat`; check with `/sandbox` |
| `statusline.py` + `statusline.pl` | `~/.claude/` (both) | Shows model, context % (with `!` past 60%) and cost. The `.pl` twin runs where there is no Python |
| `py` | `~/.claude/py` | Runs it on the first working Python 3 (skips the Windows Store and macOS stubs), else on Perl, which comes with git |

Notes:
- `~/.claude/CLAUDE.md` imports your profile from outside each repo, so the first session in a repo asks to approve it.
  Say yes; "No" silently drops your profile there.
- The kit assumes your workbench is at `~/workbench`. `kb-setup` fixes the path if it isn't.
- Your company may push **managed settings** that override these. That's expected, and those win.
- `auto` permission mode is left alone. Whether to use it is a company policy call.
