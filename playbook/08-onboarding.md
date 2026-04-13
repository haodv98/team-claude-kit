# 08 — New Member Onboarding

> First day with team-claude-kit. Follow this guide top-to-bottom — estimated 20-30 minutes.

---

## Prerequisites

Before running bootstrap, ensure these are installed:

| Tool | Min version | Install |
|------|-------------|---------|
| git | any | `brew install git` |
| node | v18+ | `brew install node` or [nvm](https://github.com/nvm-sh/nvm) |
| npm | bundled with node | — |
| python3 | 3.10+ | `brew install python3` |
| claude CLI | latest | `npm install -g @anthropic-ai/claude-code` |

Optional but recommended:

```bash
brew install docker   # GitHub MCP requires Docker
```

---

## Step 1 — Clone the kit

```bash
git clone <team-claude-kit-repo-url> ~/team-claude-kit
cd ~/team-claude-kit
```

---

## Step 2 — Copy secrets template

```bash
cp .env.example .env.local
```

Open `.env.local` and fill in your tokens. Get them from:

| Secret | Where to get it |
|--------|-----------------|
| `GITHUB_PERSONAL_ACCESS_TOKEN` | GitHub → Settings → Developer settings → Personal access tokens (scope: `repo`, `pull_requests`) |
| `SENTRY_TOKEN` | Sentry → Settings → Auth Tokens (scope: `project:read`, `event:read`) |
| `FIGMA_TOKEN` | Figma → Account → Personal access tokens |
| `BACKLOG_DOMAIN` | Your Backlog space URL, e.g. `yourteam.backlog.com` |
| `BACKLOG_API_KEY` | Backlog → Personal settings → API → Generate API key |

> **Never commit `.env.local`** — it is already in `.gitignore`.

---

## Step 3 — Run bootstrap

```bash
bash bootstrap.sh
```

Default installs for Claude target with TypeScript. For other targets:

```bash
bash bootstrap.sh --target cursor
bash bootstrap.sh --target codex
bash bootstrap.sh --languages "typescript python"
```

Bootstrap will:
- Install ECC (Everything Claude Code) → `~/everything-claude-code`
- Configure MCP servers (context7, sequential-thinking, github, sentry, figma, backlog)
- Install Graphify for knowledge graph indexing
- Add shell aliases to your RC file

---

## Step 4 — Reload your shell

```bash
source ~/.zshrc    # or ~/.bashrc
```

---

## Step 5 — Verify with cchealth

```bash
cchealth
```

All items should show ✓. Common issues and fixes:

| Symptom | Fix |
|---------|-----|
| `ECC chưa cài` | `bash bootstrap.sh` again or manually clone ECC |
| MCP not connected | Check token in `.env.local`, then `ccupdate` |
| `alias not found` | `source ~/.zshrc` |
| `graphify` missing | `pip3 install graphifyy --break-system-packages` |
| BACKLOG_DOMAIN/BACKLOG_API_KEY missing | Fill in `.env.local` and rerun `bash bootstrap.sh` |

---

## Step 6 — Start your first session

```bash
ccstart    # starts 5h session timer + opens Claude
```

---

## Daily workflow reference

| Alias | When to use |
|-------|-------------|
| `ccmorning` | Start of day — pulls Backlog issues, suggests priorities |
| `ccstart` | Open Claude with session timer |
| `ccclaim <task-id> <path>` | Before touching a file/module |
| `ccunclaim <task-id>` | After finishing a task |
| `ccclaimed` | See who's working on what |
| `cceod` | End of day — logs commits, updates Backlog |
| `ccupdate` | Keep kit + MCP servers up to date |
| `cchealth` | Diagnose any setup issues |

---

## Claiming tasks (conflict prevention)

Always claim before you start work:

```bash
ccclaim PROJ-123 src/auth/          # claim a directory
ccclaim PROJ-456 src/api/users.ts   # claim a single file
CLAIM_ETA=Tomorrow ccclaim PROJ-789 src/payments/  # with ETA
```

Check active claims before starting:

```bash
ccclaimed
```

Release when done:

```bash
ccunclaim PROJ-123
ccunclaim all    # release all your claims
```

Claims older than 24h are automatically flagged as stale by `cchealth`.

---

## Troubleshooting

**Bootstrap fails at ECC step**
```bash
# Clone manually then re-run
git clone --depth=1 https://github.com/affaan-m/everything-claude-code.git ~/everything-claude-code
bash bootstrap.sh
```

**MCP servers not connecting**
```bash
claude mcp list    # see what's installed
ccupdate           # refresh all MCP servers
```

**Backlog MCP not syncing**
```bash
# Verify credentials
grep BACKLOG .env.local

# Manually test
claude --print "Dùng Backlog MCP để lấy danh sách projects"
```

**Stale claims blocking you**
```bash
bash scripts/claim-task.sh --unclaim-stale   # release all >24h claims
```

**Full reset**
```bash
bash bootstrap.sh --rollback   # restore previous config
bash bootstrap.sh              # fresh install
```

---

## Getting help

- Run `cchealth` first — it catches 90% of issues
- Check `playbook/07-daily-workflow.md` for workflow patterns
- Check `playbook/05-team-workflows.md` for team conventions
- Ask in the team channel with output of `cchealth`
