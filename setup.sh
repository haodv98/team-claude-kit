#!/bin/bash
# bootstrap.sh — team-claude-kit setup script
# Usage: bash bootstrap.sh [--dry-run] [--backup] [--no-backup] [--yes|-y] [-v|--verbose] [--rollback]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="${TEAM_CLAUDE_KIT_DIR:-$HOME/team-claude-kit}"
BACKUP_DIR="$HOME/team-claude-kit-backup-$(date +%Y%m%d-%H%M%S)"
CLAUDE_HOME="$HOME/.claude"

# ─── Flags ────────────────────────────────────────────────────────
DRY_RUN=false
BACKUP=false
PROMPT_BACKUP=true
YES_TO_ALL=false
VERBOSE=false

# Auto-detect non-interactive (piped stdin)
[ ! -t 0 ] && YES_TO_ALL=true

for arg in "$@"; do
  case $arg in
    --dry-run)   DRY_RUN=true;         shift ;;
    --backup)    BACKUP=true; PROMPT_BACKUP=false; shift ;;
    --no-backup) BACKUP=false; PROMPT_BACKUP=false; shift ;;
    --yes|-y)    YES_TO_ALL=true;      shift ;;
    -v|--verbose) VERBOSE=true;        shift ;;
    --rollback)
      log_info "Rolling back..."
      rollback_transaction 2>/dev/null || { echo "Nothing to rollback"; exit 1; }
      exit $? ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--dry-run] [--backup] [--no-backup] [--yes|-y] [-v|--verbose] [--rollback]"
      exit 1 ;;
  esac
done

# ─── Colors & logging ────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_info()    { echo -e "${CYAN}→${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
log_header()  { echo -e "\n${BOLD}${CYAN}$1${NC}"; printf '─%.0s' {1..50}; echo; }
log_verbose() { [ "$VERBOSE" = true ] && echo -e "  ${NC}$1${NC}"; }

execute() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] $*"
    return 0
  fi
  log_verbose "$ $*"
  eval "$@"
}

ask() {
  # ask "Question?" → returns 0 (yes) or 1 (no)
  local prompt="$1"
  [ "$YES_TO_ALL" = true ] && return 0
  [ ! -t 0 ]               && return 0
  read -r -p "$(echo -e "${YELLOW}?${NC} $prompt (y/n) ")" -n 1
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# ─── TMPDIR: avoid cross-device link errors ───────────────────────
setup_tmpdir() {
  local tmp="$HOME/.claude/tmp"
  mkdir -p "$tmp" 2>/dev/null || true
  export TMPDIR="$tmp"
}

# ─── Rollback support ────────────────────────────────────────────
TRANSACTION_LOG="$HOME/.claude/tmp/bootstrap-transaction.log"
mkdir -p "$(dirname "$TRANSACTION_LOG")" 2>/dev/null || true

record_action() { echo "$*" >> "$TRANSACTION_LOG" 2>/dev/null || true; }

rollback_transaction() {
  [ ! -f "$TRANSACTION_LOG" ] && echo "No transaction log found" && return 1
  log_warning "Rolling back $(wc -l < "$TRANSACTION_LOG") action(s)..."
  tac "$TRANSACTION_LOG" | while IFS= read -r action; do
    log_info "Reverting: $action"
    eval "$action" 2>/dev/null || log_warning "Could not revert: $action"
  done
  rm -f "$TRANSACTION_LOG"
  log_success "Rollback complete"
}

# ─── Safe directory copy (rsync-preferred, node_modules excluded) ─
safe_copy_dir() {
  local src="$1" dst="$2"
  [ "$DRY_RUN" = true ] && log_info "[DRY RUN] Would copy $src → $dst" && return 0
  mkdir -p "$(dirname "$dst")"
  if command -v rsync &>/dev/null; then
    rsync -a --ignore-errors \
      --exclude "node_modules" --exclude "node_modules/**" \
      "$src/" "$dst/" 2>/dev/null && return 0
  fi
  # Fallback: manual copy
  mkdir -p "$dst"
  local skipped=0
  while IFS= read -r f; do
    local rel="${f#$src/}"
    local dest_f="$dst/$rel"
    mkdir -p "$(dirname "$dest_f")"
    cp "$f" "$dest_f" 2>/dev/null || { ((skipped++)); log_verbose "Skipped: $rel"; }
  done < <(find "$src" -type d -name node_modules -prune -o -type f -print 2>/dev/null)
  [ $skipped -gt 0 ] && log_verbose "Skipped $skipped busy file(s)"
}

# ─── 1. PREFLIGHT ─────────────────────────────────────────────────
preflight_check() {
  log_header "1. Preflight checks"
  local missing=()
  for tool in awk sed grep cat head tail date basename; do
    command -v "$tool" &>/dev/null || missing+=("$tool")
  done
  [ ${#missing[@]} -gt 0 ] && log_error "Missing: ${missing[*]}" && exit 1
  log_success "Core tools available"
}

# ─── 2. PREREQUISITES ────────────────────────────────────────────
check_prerequisites() {
  log_header "2. Prerequisites"

  # Git
  command -v git &>/dev/null && log_success "git $(git --version | awk '{print $3}')" \
    || { log_error "git not found — install from https://git-scm.com"; exit 1; }

  # Node/Bun
  if command -v bun &>/dev/null; then
    log_success "bun $(bun --version)"
  elif command -v node &>/dev/null; then
    local nv; nv=$(node -e "process.exit(parseInt(process.versions.node)<18?1:0)" 2>/dev/null && node --version || true)
    [ -z "$nv" ] && log_error "Node.js >= 18 required. Current: $(node --version)" && exit 1
    log_success "node $nv"
    log_warning "Bun preferred for hooks — install: brew install oven-sh/bun/bun"
  else
    log_warning "Neither bun nor node found"
    if ask "Install Bun now?"; then
      log_info "Installing Bun..."
      curl -fsSL https://bun.sh/install | bash
      export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
      export PATH="$BUN_INSTALL/bin:$PATH"
      command -v bun &>/dev/null && log_success "Bun $(bun --version)" \
        || { log_error "Bun installed but not in PATH — restart terminal"; exit 1; }
    else
      log_error "Node.js or Bun required. Aborting."
      exit 1
    fi
  fi

  # Claude Code
  if ! command -v claude &>/dev/null; then
    log_warning "Claude Code not found"
    if ask "Install Claude Code now?"; then
      execute "npm install -g @anthropic-ai/claude-code"
      log_success "Claude Code $(claude --version)"
    else
      log_warning "Continuing without Claude Code (MCP/plugin steps will be skipped)"
    fi
  else
    log_success "claude $(claude --version)"
  fi
}

# ─── 3. BACKUP ───────────────────────────────────────────────────
backup_configs() {
  log_header "3. Backup"

  # Cleanup old backups (keep last 5)
  local backup_parent; backup_parent="$(dirname "$BACKUP_DIR")"
  if [ -d "$backup_parent" ]; then
    local old_backups
    old_backups=$(ls -dt "$backup_parent"/team-claude-kit-backup-* 2>/dev/null | tail -n +6)
    [ -n "$old_backups" ] && echo "$old_backups" | xargs rm -rf && log_verbose "Old backups cleaned"
  fi

  if [ "$PROMPT_BACKUP" = true ]; then
    ask "Backup existing ~/.claude configs?" && BACKUP=true || BACKUP=false
  fi

  [ "$BACKUP" = false ] && log_info "Backup skipped" && return 0

  log_info "Backing up to $BACKUP_DIR..."
  execute "mkdir -p $BACKUP_DIR"
  [ -d "$CLAUDE_HOME" ] && safe_copy_dir "$CLAUDE_HOME" "$BACKUP_DIR/claude" \
    && record_action "safe_copy_dir '$BACKUP_DIR/claude' '$CLAUDE_HOME'"
  log_success "Backup complete: $BACKUP_DIR"
}

# ─── 4. GLOBAL TOOLS ─────────────────────────────────────────────
install_global_tools() {
  log_header "4. Global tools"

  install_tool() {
    local name="$1" check="$2" brew_pkg="$3" npm_pkg="$4" fallback_msg="$5"
    if command -v "$name" &>/dev/null; then
      log_success "$name found"
      return 0
    fi
    log_warning "$name not found — installing..."
    if [ -n "$brew_pkg" ] && command -v brew &>/dev/null; then
      execute "brew install $brew_pkg" && log_success "$name installed" && return 0
    fi
    if [ -n "$npm_pkg" ]; then
      execute "npm install -g $npm_pkg" && log_success "$name installed" && return 0
    fi
    log_warning "$name: $fallback_msg"
  }

  install_tool "jq"      ""      "jq"      ""                          "https://stedolan.github.io/jq/download/"
  install_tool "biome"   ""      ""        "@biomejs/biome"            "https://biomejs.dev"
  install_tool "shfmt"   ""      "shfmt"   ""                          "https://github.com/mvdan/sh"
  install_tool "ruff"    ""      "ruff"    ""                          "pip install ruff"
  install_tool "gofmt"   ""      "go"      ""                          "https://golang.org/dl/"
  install_tool "rustfmt" ""      "rust"    ""                          "https://rustup.rs"
  install_tool "stylua"  ""      "stylua"  ""                          "cargo install stylua"
  install_tool "gitnexus" ""     ""        "gitnexus"                  "npm install -g gitnexus"

  log_success "Global tools check complete"
}

# ─── 5. CREATE KIT STRUCTURE ─────────────────────────────────────
create_kit_structure() {
  log_header "5. Creating kit structure"

  if [ -d "$KIT_DIR" ] && [ "$(ls -A "$KIT_DIR" 2>/dev/null)" ]; then
    if ! ask "Directory $KIT_DIR exists. Overwrite?"; then
      log_info "Using existing kit at $KIT_DIR"
      return 0
    fi
  fi

  execute "mkdir -p $KIT_DIR"
  for d in \
    claude/{agents,skills,commands,hooks,mcp} \
    playbook scripts \
    templates/{nextjs-saas,node-api,internal-dashboard,baas-service}; do
    execute "mkdir -p $KIT_DIR/$d"
  done
  log_success "Directory structure created"
}

# ─── 6. WRITE CONFIGS ────────────────────────────────────────────
write_configs() {
  log_header "6. Writing configurations"

  # settings.json
  cat > "$KIT_DIR/claude/settings.json" << 'JSON'
{
  "model": "claude-sonnet-4-6",
  "hooks": {
    "SessionStart": [{ "command": "node ~/.claude/hooks/session-start.js" }],
    "PreToolUse":   [{ "command": "node ~/.claude/hooks/pre-tool.js" }],
    "PostToolUse":  [{ "command": "node ~/.claude/hooks/post-tool.js" }],
    "Stop":         [{ "command": "node ~/.claude/hooks/session-summary.js" }]
  },
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"]
    },
    "sentry": {
      "type": "http",
      "url": "https://mcp.sentry.dev/mcp",
      "headers": { "Authorization": "Bearer ${SENTRY_TOKEN}" }
    },
    "figma": {
      "type": "http",
      "url": "https://mcp.figma.com/mcp",
      "headers": { "Authorization": "Bearer ${FIGMA_TOKEN}" }
    }
  },
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true,
    "everything-claude-code@everything-claude-code": true,
    "claude-supermemory@rohitg00": true
  }
}
JSON
  log_success "settings.json"

  # CLAUDE.md
  cat > "$KIT_DIR/claude/CLAUDE.md" << 'MD'
# Team Claude Kit — Context

## Identity
Senior TypeScript/Next.js engineer. Sonnet mặc định.
Hỏi trước khi switch Opus. Báo complexity trước khi bắt đầu task lớn.

## Stack
Node.js 24 LTS, pnpm 9+, Next.js 16 (App Router), TypeScript strict,
Tailwind 4, shadcn/ui, Hono/Express, Zod, PostgreSQL + Prisma

## Quy tắc trước khi làm task
Task nhỏ (< 2 files) → làm ngay
Task vừa (2-5 files) → liệt kê files, đợi confirm
Task lớn (5+ files) → invoke explorer agent, plan, đợi "APPROVED"

## Code standards
- TypeScript strict — không any, không unsafe cast
- Zod cho mọi input validation
- Error: throw new AppError(code, message, statusCode)
- Named exports — không default export trừ Next.js pages
- kebab-case files, PascalCase components
- API response: { data, error, meta }
- use context7 khi làm việc với thư viện ngoài

## Concurrency
SAFE (song song): FileRead, Grep, Glob, git read, SELECT
EXCLUSIVE (tuần tự): FileWrite, FileEdit, migration, npm install, git push
Default EXCLUSIVE. Abort nếu EXCLUSIVE bash fail.

## Cần confirm team
Schema change, dependency mới, API contract change, auth flow change

## KHÔNG làm (hard limits)
rm -rf, DROP TABLE/DATABASE, git push --force, curl|bash, eval, .env.production
MD
  log_success "CLAUDE.md"
}

# ─── 7. WRITE AGENTS ─────────────────────────────────────────────
write_agents() {
  log_header "7. Writing agents"
  local dir="$KIT_DIR/claude/agents"

  cat > "$dir/explorer.md" << 'MD'
---
name: explorer
description: Khám phá codebase READ-ONLY tuyệt đối
tools: [Read, Grep, Glob, Bash]
model: sonnet
when_to_use: Khi cần hiểu codebase trước khi làm thay đổi
---

=== CRITICAL: READ-ONLY — KHÔNG SỬA BẤT KỲ FILE NÀO ===

1. Đọc .claude/graph/index.md nếu có (không quét lại src/)
2. Fallback: find src -name "*.ts" | head -30
3. Trace từ entry points, chỉ đọc file liên quan
4. Báo cáo: files liên quan, dependencies, rủi ro schema/API

Bash được phép: find, ls, cat, grep, rg, git log/diff/status
Bash KHÔNG: rm, mv, cp, mkdir, git commit/push, npm install

Kết thúc: "Files cần đọc để thực hiện task: [list]"
MD

  cat > "$dir/verifier.md" << 'MD'
---
name: verifier
description: Adversarial QA — tìm lỗi không phải xác nhận đúng
tools: [Read, Grep, Glob, Bash]
model: sonnet
when_to_use: Sau khi builder xong, trước khi tạo PR
---

Nhiệm vụ: TÌM CÁCH PHÁ code, không confirm nó hoạt động.

Tránh: (1) Tường thuật sẽ test gì rồi ghi PASS không chạy thật
       (2) Thấy UI đẹp → PASS, bỏ qua edge cases

Tier 1 (bắt buộc): pnpm test, pnpm typecheck, pnpm lint, happy path
Tier 2 (edges): null/undefined, concurrent, error handling, auth
Tier 3 (security): injection, sensitive data, N+1, rate limit

Output: VERDICT: SHIP / NEEDS FIX + danh sách critical/minor issues
Viết test vào /tmp, dọn dẹp sau.
MD

  cat > "$dir/planner.md" << 'MD'
---
name: planner
description: Kiến trúc sư READ-ONLY — phân tích và thiết kế plan
tools: [Read, Grep, Glob, Bash]
model: sonnet
when_to_use: Task lớn cần architectural plan trước khi code
---

READ-ONLY. Output: summary codebase liên quan, architectural options
+ trade-offs, implementation plan (steps, files, deps), risk assessment,
complexity estimate (Low/Medium/High), model recommendation.
MD

  cat > "$dir/code-reviewer.md" << 'MD'
---
name: code-reviewer
description: Review code — security, types, conventions
tools: [Read, Grep, Glob]
model: sonnet
when_to_use: Review PR hoặc sau khi hoàn thành feature
---

Review với vai trò senior dev. READ-ONLY.
Check: security (input validation, auth), type safety (any, null),
error handling (silent errors), conventions (CLAUDE.md), performance (N+1).
Output theo severity: Critical / Warning / Suggestion
MD

  cat > "$dir/security-auditor.md" << 'MD'
---
name: security-auditor
description: Security audit chuyên sâu
tools: [Read, Grep, Glob]
model: opus
when_to_use: Trước production release hoặc khi có security concern
---

Focus: JWT/session, injection (SQL/XSS/cmd), data leakage,
API (rate limit, CORS, auth bypass), outdated deps với CVEs.
Output: Severity, attack vector, remediation cụ thể.
MD

  cat > "$dir/db-migration-advisor.md" << 'MD'
---
name: db-migration-advisor
description: Tư vấn schema change an toàn
tools: [Read, Grep, Glob]
model: sonnet
when_to_use: Khi cần thay đổi Prisma schema
---

READ-ONLY. Phân tích: impact (tables, indexes, FKs), data migration cần không,
strategy (additive-first nếu có thể), rollback plan.
Output: Risk (Low/Med/High), migration steps, rollback plan.
MD

  log_success "6 agents"
}

# ─── 8. WRITE SKILLS ─────────────────────────────────────────────
write_skills() {
  log_header "8. Writing skills"
  local dir="$KIT_DIR/claude/skills"

  cat > "$dir/adaptive-thinking.md" << 'MD'
---
name: adaptive-thinking
description: Quyết định khi nào bật thinking và model nào
---

Không thinking (Sonnet): CRUD, components, lint fixes, tests, refactor nhỏ
Think light — "think step by step": task 3+ files, debug sau 2 lần thử, API mới
Think deep — Opus + "think hard": architecture decision, security-critical, bug intermittent

Báo cáo khi bắt đầu task lớn:
Complexity/Files/Risk: [Low|Med|High], Model: [Sonnet|Opus], Thinking: [None|Light|Deep]
Hỏi confirm nếu khuyến nghị Opus.
MD

  cat > "$dir/concurrency-aware.md" << 'MD'
---
name: concurrency-aware
description: Phân loại SAFE/EXCLUSIVE trước khi thực thi nhiều tasks
---

SAFE: FileRead, Grep, Glob, git read, SELECT, lint, typecheck
EXCLUSIVE: FileWrite, FileEdit, migration, install, commit, push, DELETE/UPDATE

Default EXCLUSIVE. Plan trước:
[Batch 1 parallel] SAFE tasks...
[Serial] EXCLUSIVE task
[Batch 2 parallel] SAFE tasks...

Abort nếu EXCLUSIVE bash fail. Chỉ EXCLUSIVE mới modify shared context.
MD

  cat > "$dir/debug-systematic.md" << 'MD'
---
name: debug-systematic
description: 4-phase debug — root cause trước khi sửa
when_to_use: Bug không rõ nguyên nhân sau 1 lần thử
paths: ["**/*.ts", "**/*.tsx", "**/*.js"]
---

KHÔNG sửa trước khi xong Phase 2.

Phase 1 — Observe: đọc error đầy đủ, xác định where/when/conditions, REPRODUCE
Phase 2 — Hypothesize: trace call stack, 2-3 hypothesis, chọn cái nhất
Phase 3 — Fix: minimal, chỉ root cause, không refactor thêm
Phase 4 — Verify: reproduce gốc, related tests, edge cases

Escalation: Sonnet → Sonnet+think → Opus+think hard → human review
MD

  cat > "$dir/tdd-workflow.md" << 'MD'
---
name: tdd-workflow
description: Red-Green-Refactor cycle
when_to_use: Viết feature mới hoặc cần tests
---

RED: Viết test fail trước. Confirm thấy fail đúng lý do.
GREEN: Code minimal nhất để pass. Không over-engineer.
REFACTOR: Clean up, tests vẫn pass. Commit sau mỗi cycle.
MD

  cat > "$dir/continuous-learning.md" << 'MD'
---
name: continuous-learning
description: Lưu pattern/lesson khi học được gì mới
---

Khi fix bug khó hoặc tìm workaround mới → lưu vào .claude/memory.md:

## [Date] — [Gotcha|Pattern|Decision]
[Mô tả], Context: [khi nào gặp], Solution: [cách giải]

Trigger: sau fix bug khó, architectural decision, workaround.
Không lưu thứ hiển nhiên hoặc documented rõ.
MD

  log_success "5 skills"
}

# ─── 9. WRITE COMMANDS ───────────────────────────────────────────
write_commands() {
  log_header "9. Writing commands"
  local dir="$KIT_DIR/claude/commands"

  cat > "$dir/new-feature.md" << 'MD'
---
name: new-feature
description: Planning và triển khai feature mới
---

1. Hỏi tối đa 3 câu làm rõ yêu cầu
2. Liệt kê files thay đổi. DỪNG nếu có schema/API change — confirm team
3. Plan checklist (files tạo/sửa/test/migration). Hỏi confirm.
4. Implement: use context7, types trước, commit từng bước nhỏ
5. Self-review: TS errors? Zod? Error handling? any?
   Invoke verifier agent trước khi báo xong.
MD

  cat > "$dir/code-review.md" << 'MD'
---
name: code-review
description: Review code trước PR
---

1. Invoke code-reviewer agent
2. Invoke verifier agent (chạy tests thật)
3. Tổng hợp: Critical (phải sửa) / Warning / VERDICT: READY|NEEDS WORK
MD

  cat > "$dir/db-migration.md" << 'MD'
---
name: db-migration
description: Thay đổi schema an toàn
---

1. Invoke db-migration-advisor
2. Nếu High risk → confirm team trước
3. Tạo migration theo advisor template
4. Test local trước
5. KHÔNG chạy staging/production mà không có human approval
MD

  cat > "$dir/wrap-session.md" << 'MD'
---
name: wrap-session
description: Lưu context trước khi kết thúc session
---

Tạo session summary lưu vào .claude/sessions/YYYY-MM-DD-HHMM.md:
1. Đã hoàn thành
2. Đang dở + đang ở bước nào
3. Bước tiếp theo (cụ thể)
4. Quyết định quan trọng
5. Files đã thay đổi
6. Gotchas đang track

In đường dẫn file.
MD

  cat > "$dir/onboard.md" << 'MD'
---
name: onboard
description: Giới thiệu project cho người mới
---

Đọc: CLAUDE.md, .claude/memory.md, docs/DECISIONS.md
Giải thích: project làm gì, cấu trúc folder, cách chạy local,
3 gotchas quan trọng, git workflow, commands/agents hay dùng.
MD

  cat > "$dir/sync-kit.md" << 'MD'
---
name: sync-kit
description: Nhắc sync từ meta repo
---

Chạy: ccsync
Sau đó restart session để apply.
MD

  log_success "6 commands"
}

# ─── 10. WRITE HOOKS ─────────────────────────────────────────────
write_hooks() {
  log_header "10. Writing hooks"
  local dir="$KIT_DIR/claude/hooks"

  cat > "$dir/session-start.js" << 'JS'
#!/usr/bin/env node
// SessionStart: inject graph + session memory + project memory
const fs = require('fs'), path = require('path')
const GRAPH = path.join(process.cwd(), '.claude', 'graph', 'index.md')
const SESSION_DIRS = [
  path.join(process.cwd(), '.claude', 'sessions'),
  path.join(process.env.HOME||'', '.claude', 'sessions')
]
const MEMORY = path.join(process.cwd(), '.claude', 'memory.md')

function graphFresh(h=24) {
  if (!fs.existsSync(GRAPH)) return false
  return (Date.now() - fs.statSync(GRAPH).mtimeMs) / 3.6e6 < h
}
function latestSession() {
  for (const d of SESSION_DIRS) {
    if (!fs.existsSync(d)) continue
    const files = fs.readdirSync(d).filter(f=>f.endsWith('.md')).sort().reverse()
    if (!files.length) continue
    const p = path.join(d, files[0])
    const age = (Date.now() - fs.statSync(p).mtimeMs) / 3.6e6
    if (age > 48) continue
    return { path: p, content: fs.readFileSync(p,'utf-8'), ageH: Math.round(age) }
  }
}
function extractKey(c) {
  const want = ['## Đang dở','## Bước tiếp theo','## Quyết định quan trọng','## Gotchas']
  return c.split('\n').reduce((out, l, _, arr) => {
    if (want.some(s=>l.startsWith(s))) out.push(l)
    else if (out.length && l.startsWith('## ') && !want.some(s=>l.startsWith(s))) {}
    else if (out.length) out.push(l)
    return out
  }, []).join('\n')
}

const parts = []
if (graphFresh()) {
  parts.push('## Codebase Graph (pre-built — không quét lại src/)')
  parts.push(fs.readFileSync(GRAPH,'utf-8'))
} else {
  parts.push('## Codebase Graph\n⚠️ Graph cũ/thiếu. Chạy: pnpm graph để rebuild.')
}
const s = latestSession()
if (s) {
  parts.push(`\n## Session gần nhất (${s.ageH}h trước)`)
  parts.push(extractKey(s.content))
}
if (fs.existsSync(MEMORY)) {
  parts.push('\n## Project Memory')
  parts.push(fs.readFileSync(MEMORY,'utf-8').slice(0,2000))
}
parts.push('\n## Reminder\n- Dùng graph, không quét src/\n- use context7 với thư viện\n- Báo complexity trước task lớn')
process.stdout.write(JSON.stringify({ type:'context', content: parts.join('\n') }))
JS

  cat > "$dir/pre-tool.js" << 'JS'
#!/usr/bin/env node
// PreToolUse: block lệnh nguy hiểm + bảo vệ file nhạy cảm
const inp = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')||'{}')
const { tool, input: ti } = inp

const DANGEROUS = [
  'rm -rf','rm -r /','DROP TABLE','DROP DATABASE','DELETE FROM',
  'git push --force','git push -f','curl | bash','wget | bash',
  'eval ','| eval','chmod 777','> /dev/sda','mkfs',
  '| sh','| bash','python -c','node -e'
]
const PROTECTED = [
  '.env.production','.env.prod','prisma/migrations',
  '.git/config','/etc/','/usr/','/bin/','/sbin/'
]

function block(reason) {
  process.stdout.write(JSON.stringify({ block:true, reason }))
  process.exit(0)
}

if (tool === 'Bash' && ti?.command) {
  const cmd = ti.command.toLowerCase()
  for (const d of DANGEROUS)
    if (cmd.includes(d.toLowerCase()))
      block(`Lệnh nguy hiểm: "${d}". Confirm thủ công trước.`)
}
if ((tool==='FileWrite'||tool==='FileEdit') && ti?.path)
  for (const p of PROTECTED)
    if (ti.path.includes(p))
      block(`Protected path: "${ti.path}". Confirm thủ công.`)

process.stdout.write(JSON.stringify({ block:false }))
JS

  cat > "$dir/post-tool.js" << 'JS'
#!/usr/bin/env node
// PostToolUse: audit log
const fs = require('fs'), path = require('path')
const inp = JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')||'{}')
const logDir = path.join(process.cwd(), '.claude')
const logFile = path.join(logDir, 'audit.log')
try {
  fs.mkdirSync(logDir, { recursive:true })
  fs.appendFileSync(logFile, JSON.stringify({
    ts: new Date().toISOString(),
    tool: inp.tool,
    input: JSON.stringify(inp.input||{}).slice(0,200),
    ok: !inp.error
  }) + '\n')
} catch(_) {}
JS

  cat > "$dir/session-summary.js" << 'JS'
#!/usr/bin/env node
// Stop: trigger Claude to create session summary
const fs = require('fs'), path = require('path')
const d = new Date()
const ts = d.toISOString().slice(0,16).replace('T','-').replace(':','')
const sessDir = path.join(process.cwd(), '.claude', 'sessions')
fs.mkdirSync(sessDir, { recursive:true })
const outFile = path.join(sessDir, `${ts}.md`)
process.stdout.write(JSON.stringify({
  type: 'inject',
  content: `Tạo session summary lưu vào ${outFile} với format:
# Session: ${d.toLocaleString('vi-VN')}
## Đã hoàn thành
## Đang dở
## Bước tiếp theo
## Quyết định quan trọng
## Files đã thay đổi
## Gotchas`
}))
JS

  chmod +x "$dir/"*.js
  log_success "4 hooks"
}

# ─── 11. WRITE PLAYBOOK ───────────────────────────────────────────
write_playbook() {
  log_header "11. Writing playbook"

  cat > "$KIT_DIR/playbook/01-prompt-patterns.md" << 'MD'
# Prompt Patterns

## Nguyên tắc
1. Constraint trước, yêu cầu sau
2. Scope cụ thể: file + function + behavior
3. Output format rõ ràng
4. use context7 với thư viện ngoài

## Constraint-first
"Đừng tạo file mới. Chỉ sửa src/auth/login.ts để thêm rate limiting."

## Scope cụ thể
"Trong src/auth/session.ts function refreshToken():
- Thêm expiry check, return AppError('TOKEN_EXPIRED')
- Không thay đổi signature. use context7 cho Auth.js v5"

## Plan-then-execute
"Trước khi code: files nào thay đổi, breaking changes nào, migration cần gì.
Đợi confirm rồi mới bắt đầu."

## Follow existing
"Đọc src/api/users.ts và products.ts.
Thêm /api/orders theo đúng pattern của 2 file trên."

## Anti-patterns
✗ "Fix everything"         → ✓ "Fix lỗi X trong file Y"
✗ Paste toàn codebase      → ✓ Paste file liên quan
✗ "You decide"             → ✓ 2-3 options + hỏi trade-off
✗ Không nói output format  → ✓ "Trả lời dạng diff/code only/bullet"
MD

  cat > "$KIT_DIR/playbook/02-context-management.md" << 'MD'
# Context Management

## Dấu hiệu rot
Claude hỏi lại thứ đã giải thích, code không follow conventions,
câu trả lời dài lặp lại, bắt đầu dùng `any`.

## Khi thấy rot: DỪNG
/wrap-session → /clear → load session file → tiếp tục
KHÔNG giải thích thêm khi Claude đang confused — làm worse.

## 5-layer defense (từ Claude Code architecture)
L1: Truncate output dài — "chỉ 20 dòng đầu"
L2: Xóa tool results cũ, giữ code changes
L3: /wrap-session → /clear khi session > 2h
L4: Session mới nếu Claude bắt đầu quên
L5: Session handover file cho người khác tiếp

## Nguyên tắc
Đừng spam cùng prompt — escalate strategy.
Commit thường = context reset tự nhiên.
Load đúng file, không load hết codebase.
MD

  cat > "$KIT_DIR/playbook/03-memory-sessions.md" << 'MD'
# Memory & Sessions

## Bắt đầu session
ccstart → /using-superpowers → "Đọc session hôm qua, tiếp tục"

## Project memory (.claude/memory.md)
Tích lũy theo tháng: gotchas, decisions, workarounds, patterns.

Sau bug khó: "Lưu lesson vào .claude/memory.md: [mô tả]"
Sau sprint: "Cập nhật .claude/memory.md với decisions sprint này"

## "Quên conversation, nhớ lessons"
Session memory = ngắn hạn (2 ngày)
Project memory = dài hạn (tích lũy mãi)
MD

  cat > "$KIT_DIR/playbook/04-token-optimization.md" << 'MD'
# Token Optimization

## Model selection
Sonnet 90%: CRUD, components, fixes, tests
Opus: architecture decisions, security review, 5+ files, hard debug

## Tiết kiệm
- .claude/graph/index.md thay vì quét src/
- /fork cho task không liên quan
- Commit nhỏ = context reset tự nhiên
- Truncate: "chỉ 20 dòng đầu"
- Stop hook (không UserPromptSubmit)

## Session timer
ccstart = timer 5h + Claude | /wrap-session khi còn 10 phút
MD

  cat > "$KIT_DIR/playbook/05-team-workflows.md" << 'MD'
# Team Workflows

## Git
main ← staging ← dev/[tên]/[task]
Worktree per task. Rebase thay merge.

## Worktree
git worktree add ../project-[task] dev/[tên]/[task]
cd ../project-[task] && ccstart

## Trước PR
/code-review → git rebase origin/main → push

## Schema/API change
Dừng → db-migration-advisor agent → confirm Slack #dev

## Sync kit (thứ Hai)
ccsync
MD

  cat > "$KIT_DIR/playbook/06-agentic-os-patterns.md" << 'MD'
# Agentic OS Patterns — Từ 513K dòng Claude Code

## 8 nguyên tắc
1. Safe-by-default: không chắc → exclusive, block, ask
2. Observe behavior, không trust labels
3. Escalate, đừng retry cùng strategy
4. Constraint bằng code/config, không chỉ lời
5. Defense-in-depth: mỗi guardrail ≥ 2 lớp
6. Circuit breaker: mỗi recovery path chạy 1 lần
7. Quên conversation, nhớ lessons
8. Trách nhiệm không ủy quyền — human approve gate

## Key patterns áp dụng
P1: Đừng tin Claude "xong" — kiểm tra output thật
P2: Escalation: Sonnet → Sonnet+think → Opus+think hard → human
P3: Khi loạn: DỪNG, /wrap-session, /clear, bắt đầu lại
P6: Bạn = coordinator (plan+review), Claude = worker
P7: Agent có 2 lớp constraint: system prompt + tool subset
P9: 5-layer context defense — xem playbook/02
P11: Chỉ định hành động cụ thể trong CLAUDE.md, không chỉ tool
P15: Pattern 3 lần → skill → ccsync --push
MD

  log_success "6 playbook guides"
}

# ─── 12. WRITE SCRIPTS ───────────────────────────────────────────
write_scripts() {
  log_header "12. Writing scripts"

  # install.sh
  cat > "$KIT_DIR/scripts/install.sh" << 'SH'
#!/bin/bash
# install.sh — Onboard machine mới
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
H="$HOME/.claude"
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; N='\033[0m'
ok()  { echo -e "${G}✓${N} $1"; }
inf() { echo -e "${C}→${N} $1"; }
wrn() { echo -e "${Y}⚠${N} $1"; }

echo ""; echo "Team Claude Kit — Install"; echo "=========================="
mkdir -p "$H"/{agents,skills,commands,hooks,sessions,rules}

inf "Copying agents..."
cp "$KIT_DIR/claude/agents/"*.md "$H/agents/" 2>/dev/null && ok "agents" || wrn "No agents"
inf "Copying skills..."
cp "$KIT_DIR/claude/skills/"*.md "$H/skills/" 2>/dev/null && ok "skills" || wrn "No skills"
inf "Copying commands..."
cp "$KIT_DIR/claude/commands/"*.md "$H/commands/" 2>/dev/null && ok "commands" || wrn "No commands"
inf "Copying hooks..."
cp "$KIT_DIR/claude/hooks/"*.js "$H/hooks/" && chmod +x "$H/hooks/"*.js && ok "hooks"

[ ! -f "$H/settings.json" ] \
  && cp "$KIT_DIR/claude/settings.json" "$H/settings.json" && ok "settings.json" \
  || wrn "settings.json exists — merge thủ công nếu cần"

command -v claude &>/dev/null \
  && claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp@latest 2>/dev/null \
  && ok "Context7 MCP" \
  || wrn "Claude Code not found — add Context7 manually later"

ZSHRC="$HOME/.zshrc"
if ! grep -q "# team-claude-kit" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" << ALIASES

# team-claude-kit
alias ccstart='bash $KIT_DIR/scripts/session-timer.sh & claude'
alias cctime='bash $KIT_DIR/scripts/session-timer.sh status'
alias ccsync='bash $KIT_DIR/scripts/sync.sh'
alias ccnew='bash $KIT_DIR/scripts/create-project.sh'
ALIASES
  ok "Aliases → ~/.zshrc"
fi

echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bước thủ công trong Claude Code:"
echo "  /plugin marketplace add obra/superpowers-marketplace"
echo "  /plugin install superpowers@superpowers-marketplace"
echo ""; echo "Sau đó: source ~/.zshrc && ccstart"
SH

  # sync.sh
  cat > "$KIT_DIR/scripts/sync.sh" << 'SH'
#!/bin/bash
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
H="$HOME/.claude"
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; N='\033[0m'
ok()  { echo -e "${G}✓${N} $1"; }
inf() { echo -e "${C}→${N} $1"; }
wrn() { echo -e "${Y}⚠${N} $1"; }
MODE="${1:-both}"

inf "Kiểm tra remote updates..."
cd "$KIT_DIR"
git fetch origin --quiet 2>/dev/null || wrn "Offline hoặc no remote"
BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
  read -r -p "$(echo -e "${Y}?${N} Có $BEHIND commit mới. Pull? (y/n) ")" -n1; echo
  [[ $REPLY =~ ^[Yy]$ ]] && git pull origin main --quiet && ok "Kit updated"
else
  ok "Kit is up to date"
fi
cd - > /dev/null

[[ "$MODE" != "--project" ]] && {
  inf "Sync ~/.claude..."
  command -v rsync &>/dev/null \
    && rsync -av --update "$KIT_DIR/claude/"{agents,skills,commands,hooks}"/" "$H/"  > /dev/null \
    || { for d in agents skills commands; do cp "$KIT_DIR/claude/$d/"*.md "$H/$d/" 2>/dev/null; done; cp "$KIT_DIR/claude/hooks/"*.js "$H/hooks/"; }
  ok "Global ~/.claude synced"
}

[[ "$MODE" == "--push" ]] && {
  echo "Đóng góp: 1) Command  2) Agent  3) Skill  4) CLAUDE.md"
  read -r -p "Chọn: " T
  case $T in
    1) S=".claude/commands"; D="$KIT_DIR/claude/commands" ;;
    2) S=".claude/agents";   D="$KIT_DIR/claude/agents" ;;
    3) S=".claude/skills";   D="$KIT_DIR/claude/skills" ;;
    4) diff "CLAUDE.md" "$KIT_DIR/claude/CLAUDE.md" || true
       read -r -p "Copy CLAUDE.md vào kit? (y/n) " -n1; echo
       [[ $REPLY =~ ^[Yy]$ ]] && cp "CLAUDE.md" "$KIT_DIR/claude/CLAUDE.md" && ok "Copied"
       echo "cd $KIT_DIR && git add . && git commit && git push"; exit 0 ;;
  esac
  ls "$S/" 2>/dev/null
  read -r -p "Tên file: " F
  cp "$S/$F" "$D/$F" && ok "Pushed $F"
  echo "cd $KIT_DIR && git add . && git commit -m 'feat: add $F' && git push"
}
echo ""; ok "Sync hoàn tất"
SH

  # create-project.sh
  cat > "$KIT_DIR/scripts/create-project.sh" << 'SH'
#!/bin/bash
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
G='\033[0;32m'; C='\033[0;36m'; N='\033[0m'
ok()  { echo -e "${G}✓${N} $1"; }
inf() { echo -e "${C}→${N} $1"; }

echo ""; echo "Tạo project mới"
echo "1) nextjs-saas  2) node-api  3) internal-dashboard  4) baas-service"
read -r -p "Template (1-4): " C2
case $C2 in 1) T="nextjs-saas";; 2) T="node-api";; 3) T="internal-dashboard";; 4) T="baas-service";; *) echo "Invalid"; exit 1;; esac
read -r -p "Tên project (kebab-case): " NAME
[[ -z "$NAME" ]] && echo "Tên không được trống" && exit 1
read -r -p "Thư mục đích [../]: " TARGET; TARGET="${TARGET:-../}"
DEST="$TARGET/$NAME"
[[ -d "$DEST" ]] && echo "Thư mục đã tồn tại" && exit 1

inf "Tạo $NAME từ $T..."
cp -r "$KIT_DIR/templates/$T" "$DEST" 2>/dev/null || mkdir -p "$DEST"
find "$DEST" -type f \( -name "*.json" -o -name "*.md" -o -name "*.ts" \) \
  -exec sed -i.bak "s/TEMPLATE_PROJECT_NAME/$NAME/g" {} + 2>/dev/null; find "$DEST" -name "*.bak" -delete

mkdir -p "$DEST/.claude/sessions"
cp "$KIT_DIR/claude/CLAUDE.md" "$DEST/CLAUDE.md"
cp "$KIT_DIR/claude/settings.json" "$DEST/.claude/settings.json"
cp -r "$KIT_DIR/claude/commands" "$DEST/.claude/"
cp -r "$KIT_DIR/claude/agents" "$DEST/.claude/"

cd "$DEST" && git init --quiet && git add . && git commit -m "chore: init from $T template" --quiet
ok "Project $NAME → $DEST"
echo ""; echo "Tiếp theo:"; echo "  cd $DEST && cp .env.example .env.local && pnpm install && ccstart"
SH

  # session-timer.sh
  cat > "$KIT_DIR/scripts/session-timer.sh" << 'SH'
#!/bin/bash
SESSION_DURATION=$((5*60*60))
WARN_BEFORE=600
SESSION_FILE="$HOME/.claude/sessions/.current-timer"

notify() {
  command -v osascript &>/dev/null \
    && osascript -e "display notification \"$1\" with title \"$2\" sound name \"${3:-Glass}\"" 2>/dev/null \
    || echo "$2: $1"
}

if [[ "$1" == "status" ]]; then
  [[ ! -f "$SESSION_FILE" ]] && echo "Không có session đang chạy" && exit 0
  START=$(cat "$SESSION_FILE"); ELAPSED=$(($(date +%s)-START)); LEFT=$((SESSION_DURATION-ELAPSED))
  printf "Đã dùng: %d phút | Còn lại: %d phút\n" $((ELAPSED/60)) $((LEFT/60))
  exit 0
fi

mkdir -p "$(dirname "$SESSION_FILE")"
date +%s > "$SESSION_FILE"
RESET=$(date -v+${SESSION_DURATION}S '+%H:%M' 2>/dev/null || date -d "+${SESSION_DURATION} seconds" '+%H:%M')
echo "⏱  Session bắt đầu — reset lúc $RESET"

sleep $((SESSION_DURATION-WARN_BEFORE))
notify "Còn 10 phút — /wrap-session ngay!" "Claude Code ⏰"
echo "⚠️  CÒN 10 PHÚT — chạy /wrap-session"
sleep 300; notify "Còn 5 phút!" "Claude Code 🔴" "Basso"; echo "🔴 CÒN 5 PHÚT"
sleep 240; notify "Còn 1 phút!" "Claude Code 💀" "Sosumi"; echo "💀 CÒN 1 PHÚT"
sleep 60;  notify "Session reset!" "Claude Code ✅" "Hero"; echo "✅ Reset — ccstart"
rm -f "$SESSION_FILE"
SH

  chmod +x "$KIT_DIR/scripts/"*.sh
  log_success "4 scripts"
}

# ─── 13. WRITE README + CHANGELOG ────────────────────────────────
write_docs() {
  log_header "13. Writing docs"

  cat > "$KIT_DIR/README.md" << 'MD'
# Team Claude Kit

Meta repo — source of truth cho Claude Code config của team.
Mỗi project reference từ đây. Khi kit update → ccsync là xong.

## Onboard (15 phút)

```bash
git clone git@github.com:[org]/team-claude-kit.git ~/team-claude-kit
npm install -g @anthropic-ai/claude-code && claude login
cd ~/team-claude-kit && bash scripts/install.sh
source ~/.zshrc
```

Trong Claude Code (1 lần):
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

Với mỗi project mới:
```bash
cd [project] && gitnexus analyze --skills
```

## Hàng ngày
```bash
ccstart              # Claude + timer 5h
/using-superpowers   # kích hoạt planning skills
/onboard             # lần đầu vào project
/new-feature         # bắt đầu feature
/wrap-session        # trước khi đóng
ccsync               # sync kit (mỗi thứ Hai)
```

## Đóng góp
```bash
ccsync --push   # chia sẻ file hay ngược lại kit
```

## Flags
```
--dry-run    xem sẽ làm gì, không thực thi
--backup     backup ~/.claude trước
--no-backup  bỏ qua backup
--yes/-y     accept tất cả prompts
--verbose    log chi tiết
--rollback   hoàn tác lần chạy trước
```
MD

  cat > "$KIT_DIR/CHANGELOG.md" << 'MD'
# Changelog

## v2.0.0
- Production-grade bootstrap: dry-run, backup, rollback, verbose
- 6 agents: explorer, verifier, planner, code-reviewer, security-auditor, db-migration-advisor
- 5 skills: adaptive-thinking, concurrency-aware, debug-systematic, tdd-workflow, continuous-learning
- 6 commands: new-feature, code-review, db-migration, wrap-session, onboard, sync-kit
- 4 hooks: session-start, pre-tool, post-tool, session-summary
- 6 playbook guides (18 patterns từ Claude Code source)
- MCP: context7, sequential-thinking, github, sentry, figma
MD

  cat > "$KIT_DIR/.gitignore" << 'GI'
node_modules/
.DS_Store
*.log
.env*
!.env.example
.claude/tmp/
GI

  log_success "README.md + CHANGELOG.md + .gitignore"
}

# ─── 14. MCP & PLUGINS ───────────────────────────────────────────
setup_mcp_and_plugins() {
  log_header "14. MCP & Plugins"

  if ! command -v claude &>/dev/null; then
    log_warning "Claude Code not found — skipping MCP/plugin setup"
    return 0
  fi

  # MCP servers
  install_mcp() {
    local name="$1" cmd="$2" desc="$3"
    if ask "Install $name MCP ($desc)?"; then
      local err; err=$(mktemp)
      if eval "$cmd" 2>"$err"; then
        log_success "$name MCP added"
      else
        grep -qi "already" "$err" 2>/dev/null \
          && log_info "$name already installed" \
          || log_warning "$name failed — see $err"
      fi
      rm -f "$err"
    fi
  }

  install_mcp "context7" \
    "claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest" \
    "docs lookup"

  install_mcp "sequential-thinking" \
    "claude mcp add --scope user --transport stdio sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking" \
    "multi-step reasoning"

  install_mcp "gitnexus" \
    "claude mcp add --scope user --transport stdio gitnexus -- npx -y gitnexus@latest mcp" \
    "codebase knowledge graph"

  # Superpowers plugin
  if ask "Install Superpowers plugin?"; then
    setup_tmpdir
    execute "claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true"
    execute "claude plugin install superpowers@superpowers-marketplace 2>/dev/null" \
      && log_success "Superpowers installed" || log_warning "Superpowers: may already be installed"
  fi

  # Everything Claude Code plugin
  if ask "Install everything-claude-code plugin (rules + skills)?"; then
    setup_tmpdir
    execute "claude plugin marketplace add affaan-m/everything-claude-code 2>/dev/null || true"
    execute "claude plugin install everything-claude-code@everything-claude-code 2>/dev/null" \
      && log_success "everything-claude-code installed" || log_warning "May already be installed"
  fi

  log_success "MCP & plugins setup complete"
}

# ─── 15. GITNEXUS ────────────────────────────────────────────────
setup_gitnexus() {
  log_header "15. GitNexus (codebase graph)"

  if command -v gitnexus &>/dev/null; then
    log_success "gitnexus already installed"
  else
    if ask "Install GitNexus globally (knowledge graph for Claude)?"; then
      execute "npm install -g gitnexus" \
        && log_success "gitnexus installed" \
        || log_warning "gitnexus install failed — try: sudo npm install -g gitnexus"
    fi
  fi

  if command -v gitnexus &>/dev/null && ask "Run gitnexus setup (configure MCP for editors)?"; then
    execute "gitnexus setup 2>/dev/null" \
      && log_success "gitnexus setup complete" \
      || log_warning "gitnexus setup: run manually if needed"
  fi

  log_info "Với mỗi project: cd [project] && gitnexus analyze --skills"
}

# ─── 16. GIT INIT ────────────────────────────────────────────────
init_git() {
  log_header "16. Git init"
  cd "$KIT_DIR"
  if [ ! -d ".git" ]; then
    execute "git init --quiet"
    execute "git add ."
    execute "git commit -m 'chore: init team-claude-kit v2.0.0' --quiet"
    log_success "Git repository initialized"
  else
    log_info "Git already initialized"
  fi
  cd - > /dev/null
}

# ─── 17. INSTALL TO ~/.claude ────────────────────────────────────
install_to_home() {
  log_header "17. Installing to ~/.claude"
  if ask "Install kit to ~/.claude now?"; then
    bash "$KIT_DIR/scripts/install.sh"
  else
    log_info "Run manually: bash $KIT_DIR/scripts/install.sh"
  fi
}

# ─── MAIN ─────────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}"
  cat << 'EOF'
╔══════════════════════════════════════════╗
║        team-claude-kit bootstrap v2      ║
║   Setup Claude Code environment cho team ║
╚══════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  [ "$DRY_RUN" = true ] && log_warning "DRY RUN MODE — no changes will be made"
  echo "Kit dir: $KIT_DIR"
  echo ""

  preflight_check
  check_prerequisites
  backup_configs
  install_global_tools
  create_kit_structure
  write_configs
  write_agents
  write_skills
  write_commands
  write_hooks
  write_playbook
  write_scripts
  write_docs
  setup_mcp_and_plugins
  setup_gitnexus
  init_git
  install_to_home

  echo ""
  echo -e "${BOLD}${GREEN}"
  cat << 'EOF'
╔══════════════════════════════════════════╗
║     team-claude-kit v2.0.0 ✓ Done!      ║
╚══════════════════════════════════════════╝
EOF
  echo -e "${NC}"

  echo "Kit: $KIT_DIR"
  [ "$BACKUP" = true ] && echo "Backup: $BACKUP_DIR"
  echo ""
  echo "Contents:"
  echo "  $(ls "$KIT_DIR/claude/agents/" | wc -l | tr -d ' ') agents"
  echo "  $(ls "$KIT_DIR/claude/skills/" | wc -l | tr -d ' ') skills"
  echo "  $(ls "$KIT_DIR/claude/commands/" | wc -l | tr -d ' ') commands"
  echo "  $(ls "$KIT_DIR/claude/hooks/" | wc -l | tr -d ' ') hooks"
  echo "  $(ls "$KIT_DIR/playbook/" | wc -l | tr -d ' ') playbook guides"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. source ~/.zshrc"
  echo "  2. ccstart"
  echo "  3. cd [your-project] && gitnexus analyze --skills"
  echo ""
  echo -e "${YELLOW}Superpowers (nếu chưa cài):${NC}"
  echo "  /plugin marketplace add obra/superpowers-marketplace"
  echo "  /plugin install superpowers@superpowers-marketplace"
}

main