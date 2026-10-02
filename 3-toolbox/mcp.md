---
updated: YYYY-MM-DD
---

# MCP servers

An MCP server connects the agent to a live system. It is also a new way in for
untrusted content, so it's the riskiest thing you add.

## Rules

1. **Read-only first.** Add write tools only for a concrete need, and put them under `ask`.
2. **Per repo, not global.** Put a server in that repo's `.mcp.json`, so each session only has what it needs.
3. **Prefer the CLI** when there is one (`gh`, `az`, `kubectl`, `psql`). Cheaper and better known.
4. **No secrets in config.** Use `${ENV_VAR}`. Keep the values in your shell or a secret manager.
5. **Never `enableAllProjectMcpServers`.** Approve servers by name.

## Vetting checklist (`kb-vet` runs this)

- [ ] Publisher is first-party or internal, with a maintained repo
- [ ] Version pinned (no bare `npx -y pkg`); the full launch command read
- [ ] Tool descriptions read: no hidden instructions, no odd Unicode. Re-check after updates
- [ ] Least-privilege token; read-only scope where it exists
- [ ] Remote servers: HTTPS, OAuth, no token passthrough
- [ ] **Trifecta:** which leg does it add (private data / untrusted content / a way out)? Does the session already have the other two?
- [ ] Output size reasonable (results over 25k tokens are cut off and crowd the context)

## Register

| Server | Gives | Access | Pinned | Where | Vetted |
|--------|-------|--------|--------|-------|--------|
| <!-- e.g. context7 --> | <!-- current library docs --> | read | <!-- version --> | <!-- repo .mcp.json --> | <!-- date --> |

## Adding one

```bash
claude mcp add --scope project context7 -- npx -y @upstash/context7-mcp@<version>
claude mcp add --scope project --transport http <name> https://<url>
claude mcp list            # what's configured
```

Then `/mcp` in a session shows what's connected; `/context` shows what it costs.
