# Implementation Plan: team-claude-kit Unified Setup + Workflow Integration

## Architect Review Summary

### Current Kit Strengths
- `bootstrap.sh` — clean single-entry installer with `--target`, `--languages`, `--project`, `--yes`, `--dry-run`, `--rollback`
- `lib/common.sh` — solid step runner with timing + error tracking
- `lib/backup.sh` — full backup/rollback for all three targets
- `lib/mcp.sh` — Backlog MCP + 5 other MCP servers installed
- `lib/ecc.sh` — ECC version pinning + ccg-workflow npm package
- `scripts/cchealth.sh` — health check covering deps, ECC, MCP, API keys, aliases, graphify
- `scripts/claim-task.sh` — claim/unclaim with file-based + Backlog MCP sync
- `playbook/07-daily-workflow.md` — comprehensive daily schedule + git workflow

### Critical Gaps Found (architect review)

| # | Gap | Impact | File |
|---|-----|--------|------|
| 1 | **Missing 6 aliases** referenced in playbook (`ccmorning`, `ccclaim`, `ccunclaim`, `ccclaimed`, `ccbranch`, `ccsync`, `cceod`) but never added by installer | HIGH — team can't follow the playbook without them | `lib/aliases.sh` |
| 2 | **`cchealth` doesn't check Backlog** — MCP list misses `backlog`, no BACKLOG_DOMAIN/BACKLOG_API_KEY validation | HIGH — silent breakage of claim system | `scripts/cchealth.sh` |
| 3 | **Codex target skips MCP** — `bootstrap.sh` codex path omits `step_mcp` entirely | MEDIUM — Codex users get no MCP tooling | `bootstrap.sh` |
| 4 | **`ccupdate` only updates ECC** — no MCP refresh, no graphify update, no playbook sync | MEDIUM — drift over time | `lib/aliases.sh` |
| 5 | **`create-project.sh` calls `gitnexus`** — gitnexus was replaced by graphify, this will silently fail | MEDIUM — new project creation broken | inline in `lib/aliases.sh` |
| 6 | **Claim system fragile** — `claude --print` subprocess can fail silently if rate-limited or CLI absent | MEDIUM — false claim success | `scripts/claim-task.sh` |
| 7 | **No claim expiry** — stale claims block teammates indefinitely | MEDIUM — deadlock risk | `scripts/claim-task.sh` |
| 8 | **No `.env.example`** — file exists but not generated/updated by bootstrap | LOW — new member confusion | `lib/secrets.sh` or `bootstrap.sh` |
| 9 | **New member onboarding not documented** — no step-by-step first-day guide | LOW — relies on tribal knowledge | `playbook/` |

---

## Technical Solution

### Architecture Principle
**Minimal changes to existing structure.** The kit's layered lib/ + scripts/ pattern is sound. Fix gaps in place rather than redesigning.

```
bootstrap.sh
├── lib/common.sh        ← no change
├── lib/backup.sh        ← no change
├── lib/ecc.sh           ← no change
├── lib/mcp.sh           ← Gap #2: add Backlog to health validation notes
├── lib/secrets.sh       ← Gap #8: generate .env.example
├── lib/aliases.sh       ← Gap #1, #4, #5: add missing aliases + fix gitnexus ref
├── lib/codex.sh         ← Gap #3: explore MCP support for codex target
scripts/
├── cchealth.sh          ← Gap #2: add backlog check + BACKLOG_* token check
├── claim-task.sh        ← Gap #6, #7: resilient fallback + expiry
└── (new) ccsync.sh      ← separate claim/sync logic from inline heredoc
playbook/
└── (new) 08-onboarding.md  ← Gap #9: new member first-day guide
```

---

## Implementation Steps

### Step 1 — Fix Missing Aliases in `lib/aliases.sh`
**Priority: HIGH | Deliverable: All playbook aliases work after bootstrap**

The playbook documents 7 commands that don't exist post-install:

```bash
# Add to lib/aliases.sh in step_aliases(), after existing aliases:

alias ccmorning='claude --print "Chạy morning briefing: 1) Backlog MCP: lấy issues assigned to me với status != Done, 2) Kiểm tra claimed.md, 3) Đề xuất task ưu tiên cho hôm nay"'
alias ccclaim='bash "${SCRIPT_DIR}/scripts/claim-task.sh"'
alias ccunclaim='bash "${SCRIPT_DIR}/scripts/claim-task.sh" --unclaim'
alias ccclaimed='cat "${SCRIPT_DIR}/todos/claimed.md" 2>/dev/null || echo "Chưa có claimed tasks"'
alias ccbranch='git checkout -b'
alias ccsync='bash "${SCRIPT_DIR}/scripts/sync.sh"'
alias cceod='claude --print "EOD wrap: 1) List my commits today, 2) Backlog MCP: update task comments với progress, 3) Gợi ý commit message cho staged changes"'
```

Also fix `create-project.sh`: replace `gitnexus analyze --skills` with `python3 -m graphify . --no-viz 2>/dev/null && echo "✓ Indexed with Graphify"`.

---

### Step 2 — Fix `cchealth.sh`: Add Backlog MCP + Token Checks
**Priority: HIGH | Deliverable: `cchealth` catches Backlog misconfiguration**

Two additions to `scripts/cchealth.sh`:

**2a. Add `backlog` to expected MCP list (line 87):**
```bash
expected_mcps=("context7" "sequential-thinking" "github" "sentry" "figma" "backlog")
```

**2b. Add Backlog token validation (after existing check_token calls):**
```bash
check_token "BACKLOG_DOMAIN"    "Backlog Domain"
check_token "BACKLOG_API_KEY"   "Backlog API Key"
```

**2c. Add claim-task.sh existence check:**
```bash
section "Claim System"
CLAIM_SCRIPT="$SCRIPT_DIR/scripts/claim-task.sh"
if [[ -f "$CLAIM_SCRIPT" ]]; then
  ok "claim-task.sh — found"
  CLAIMED_FILE="$SCRIPT_DIR/todos/claimed.md"
  if [[ -f "$CLAIMED_FILE" ]]; then
    count=$(grep -c "^|" "$CLAIMED_FILE" 2>/dev/null || echo 0)
    ok "claimed.md — $count active claims"
    # Check for stale claims (>24h)
    _check_stale_claims "$CLAIMED_FILE"
  else
    warn "claimed.md — không tồn tại (sẽ được tạo khi claim lần đầu)"
  fi
else
  fail "claim-task.sh — không tìm thấy"
  ((ISSUES++))
fi
```

---

### Step 3 — Claim System Hardening
**Priority: MEDIUM | Deliverable: Resilient claim/unclaim with expiry detection**

Three improvements to `scripts/claim-task.sh`:

**3a. Claim expiry warning (24h)**
```bash
# After reading claimed.md, check timestamps:
_check_stale_claims() {
  local file="$1"
  local now=$(date +%s)
  while IFS='|' read -r _ task paths user timestamp _; do
    [[ "$task" == " Task " ]] && continue  # header
    [[ -z "${timestamp// }" ]] && continue
    claim_ts=$(date -d "${timestamp// /}" +%s 2>/dev/null || \
               date -j -f "%Y-%m-%d %H:%M" "${timestamp// /}" +%s 2>/dev/null || echo 0)
    age=$(( (now - claim_ts) / 3600 ))
    if [[ $age -gt 24 ]]; then
      warn "Stale claim: ${task// /} by ${user// /} (${age}h ago) — có thể đã bị bỏ quên"
    fi
  done < "$file"
}
```

**3b. Resilient Backlog sync — don't fail if claude CLI unavailable**
```bash
# Replace current claude --print block with:
_sync_to_backlog() {
  local task_ref="$1" status="$2" comment="$3"
  if command -v claude >/dev/null 2>&1; then
    claude --print "Dùng Backlog MCP: 1. Update issue $task_ref sang '$status' 2. Add comment: $comment" \
      2>/dev/null && return 0
    warn "Backlog sync via claude CLI failed — claim đã được ghi vào claimed.md (manual sync sau)"
  else
    warn "claude CLI không có — claim ghi file-only. Sync Backlog thủ công sau."
  fi
}
```

**3c. `--unclaim-stale` flag** — mass-release claims older than 24h:
```bash
# In claim-task.sh argument parsing:
--unclaim-stale)
  _unclaim_stale_claims "$CLAIMS_FILE"
  exit 0 ;;
```

---

### Step 4 — Extend `ccupdate` to Full Kit Update
**Priority: MEDIUM | Deliverable: Single command updates entire kit**

Replace the current one-liner `ccupdate` alias with a script `scripts/update.sh`:

```bash
#!/usr/bin/env bash
# scripts/update.sh — Full kit update: ECC + MCP servers + graphify + playbook

set -eo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
source "$KIT/lib/common.sh"

header "team-claude-kit update"

# 1. ECC update (existing logic)
section "ECC"
cd "$HOME/everything-claude-code"
git pull --quiet
bash install.sh --target "${TARGET:-claude}" "${LANGUAGES:-typescript}"
ok "ECC updated"

# 2. ccg-workflow update
section "ccg-workflow"
npm update -g ccg-workflow 2>/dev/null && ok "ccg-workflow updated" || warn "ccg-workflow update skipped"

# 3. Graphify update
section "Graphify"
pip install --upgrade graphifyy --quiet 2>/dev/null && ok "graphify updated" || warn "graphify update skipped"

# 4. MCP server refresh — reinstall npm-based ones
section "MCP servers"
claude mcp remove backlog 2>/dev/null || true
_mcp_add_backlog  # from lib/mcp.sh
ok "Backlog MCP refreshed"

# 5. Sync playbook from kit remote (if kit is a git repo)
section "Playbook sync"
if git -C "$KIT" remote get-url origin &>/dev/null; then
  git -C "$KIT" pull --quiet && ok "Playbook synced from remote" || warn "Playbook sync failed (offline?)"
fi

print_summary
```

Alias change in `lib/aliases.sh`:
```bash
alias ccupdate='bash "${SCRIPT_DIR}/scripts/update.sh"'
```

---

### Step 5 — Codex Target: Minimal MCP Support
**Priority: MEDIUM | Deliverable: Codex users get context7 + sequential-thinking**

`lib/codex.sh` currently doesn't install MCP. Since Codex doesn't have `claude mcp add`, but MCP config files can be placed at `~/.codex/mcp.json`, add:

```bash
# In lib/codex.sh — add after existing install logic:
step_codex_mcp() {
  section "MCP config for Codex (context7 + sequential-thinking)"
  local mcp_config="$HOME/.codex/mcp.json"
  mkdir -p "$(dirname "$mcp_config")"
  cat > "$mcp_config" << 'JSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
JSON
  ok "Codex MCP config written → $mcp_config"
}
```

Add `run_step "MCP config" step_codex_mcp` to the codex path in `bootstrap.sh`.

---

### Step 6 — Generate `.env.example`
**Priority: LOW | Deliverable: New members know what secrets to set**

In `lib/secrets.sh` (or end of `bootstrap.sh`), after `step_secrets`:

```bash
# Generate .env.example if not present
_generate_env_example() {
  local example_file="$SCRIPT_DIR/.env.example"
  [[ -f "$example_file" ]] && return 0  # don't overwrite

  cat > "$example_file" << 'EOF'
# team-claude-kit — required secrets
# Copy to .env.local and fill in values
# DO NOT commit .env.local to git

# GitHub MCP
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...

# Sentry MCP
SENTRY_TOKEN=sntrys_...

# Figma MCP
FIGMA_TOKEN=figd_...

# Backlog MCP (for claim system + daily workflow)
BACKLOG_DOMAIN=your-space.backlog.com
BACKLOG_API_KEY=your-api-key

# Optional: override ECC version
# ECC_COMMIT=abc123def
EOF
  ok ".env.example generated → $example_file"
}
```

---

### Step 7 — New Member Onboarding Playbook
**Priority: LOW | Deliverable: Zero-to-productive in <30 min**

Create `playbook/08-onboarding.md`:

```markdown
# 08 — New Member Onboarding

## Day 1 Setup (< 30 minutes)

### Prerequisites
- [ ] Node.js v18+ installed (`node --version`)
- [ ] Python 3.10+ installed (`python3 --version`)
- [ ] Git configured (`git config user.email`)
- [ ] Received `.env.local` from team lead (NEVER commit this)

### Step 1: Run bootstrap
\`\`\`bash
git clone <kit-repo> team-claude-kit && cd team-claude-kit
cp /path/to/.env.local .env.local   # received from team lead
bash bootstrap.sh --target claude --languages typescript --yes
source ~/.zshrc
\`\`\`

### Step 2: Verify
\`\`\`bash
cchealth   # should show 0 issues
\`\`\`

### Step 3: First task
\`\`\`bash
ccmorning              # get today's task suggestions
ccclaim PROJ-123 src/  # claim your first task
ccbranch feat/proj-123-description
\`\`\`

## Troubleshooting
| Symptom | Fix |
|---------|-----|
| `cchealth` shows MCP errors | Run `bash bootstrap.sh --yes` again |
| Backlog MCP not connecting | Check BACKLOG_DOMAIN / BACKLOG_API_KEY in .env.local |
| ECC not updating | `ccupdate` — needs internet |
| Alias not found | `source ~/.zshrc` |
| Claim fails silently | `ccclaimed` to check state, Backlog sync is best-effort |
```

---

## Key Files Changed

| File | Operation | Description |
|------|-----------|-------------|
| `lib/aliases.sh` | Modify | Add 7 missing aliases + fix gitnexus ref |
| `scripts/cchealth.sh` | Modify | Add backlog MCP + BACKLOG_* token check + claim system check |
| `scripts/claim-task.sh` | Modify | Resilient Backlog sync + stale claim detection + `--unclaim-stale` flag |
| `scripts/update.sh` | Create | New comprehensive update script (ECC + MCP + graphify + playbook) |
| `lib/codex.sh` | Modify | Add `step_codex_mcp` for context7 + sequential-thinking config |
| `bootstrap.sh` | Modify | Add `step_codex_mcp` to codex path; call `_generate_env_example` |
| `lib/secrets.sh` | Modify | Add `_generate_env_example` function |
| `playbook/08-onboarding.md` | Create | New member guide |
| `.env.example` | Create | Secret template (commit this, not .env.local) |

---

## Risks and Mitigation

| Risk | Mitigation |
|------|------------|
| `ccupdate` runs `pip install` — breaks system Python | Use `pip install --user` or detect venv; add `--break-system-packages` as fallback |
| Codex MCP JSON format may change | Document version, add schema validation in `step_codex_mcp` |
| Stale claim detection: timestamp parsing differs macOS/Linux | Use two-path `date` parsing (GNU + BSD) — same pattern already in `session-timer.sh` |
| `claude --print` rate limit during claim sync | Already mitigated by resilient fallback in Step 3b |
| bootstrap.sh step ordering for `_generate_env_example` | Call it at end of `main()`, after all steps, so it's always the final output |

---

## SESSION_ID (for /ccg:execute use)
- CODEX_SESSION: N/A (codeagent-wrapper not available)
- GEMINI_SESSION: N/A (codeagent-wrapper not available)
