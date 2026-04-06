#!/usr/bin/env bash
# lib/codex.sh — OpenAI Codex CLI setup
# Chạy standalone: bash bootstrap.sh --target codex --languages typescript

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ECC_DIR="$HOME/everything-claude-code"
KIT_DIR="$SCRIPT_DIR"

step_codex() {
  # ── 1. Cài Codex CLI ──────────────────────────────────────────
  step "Codex CLI install"
  if has codex; then
    ok "codex already installed ($(codex --version 2>/dev/null || echo 'unknown'))"
  else
    if ask "Cài Codex CLI?"; then
      local tmp; tmp=$(mktemp)
      if run "npm install -g @openai/codex" > "$tmp" 2>&1; then
        ok "Codex CLI installed"
      else
        warn "npm install failed:"; sed 's/^/    /' "$tmp"
        rm -f "$tmp"; return 1
      fi
      rm -f "$tmp"
    else
      info "Bỏ qua. Cài sau: npm install -g @openai/codex"
      return 0
    fi
  fi

  # ── 2. Tạo ~/.codex/ ──────────────────────────────────────────
  step "Codex config directory"
  run "mkdir -p '$CODEX_HOME/skills'"
  ok "~/.codex/ ready"

  # ── 3. config.toml ────────────────────────────────────────────
  step "Codex config.toml"
  _write_codex_config
  ok "~/.codex/config.toml written"

  # ── 4. AGENTS.md (global) ─────────────────────────────────────
  step "Codex global AGENTS.md"
  _write_agents_md
  ok "~/.codex/AGENTS.md written"

  # ── 5. Skills từ ECC ──────────────────────────────────────────
  step "Codex skills từ ECC"
  _install_ecc_skills_for_codex

  # ── 6. Skills từ kit ─────────────────────────────────────────
  step "Codex skills từ team-claude-kit"
  _install_kit_skills_for_codex

  # ── 7. MCP servers ────────────────────────────────────────────
  step "Codex MCP servers"
  _setup_codex_mcp

  # ── 8. Gitnexus analyze ───────────────────────────────────────
  step "GitNexus: thêm AGENTS.md vào project fallback"
  _patch_codex_config_fallback

  info "Codex setup hoàn tất"
  info "Chạy: codex"
  info "Hoặc non-interactive: codex --full-auto \"<task>\""
}

# ── config.toml ───────────────────────────────────────────────────
_write_codex_config() {
  local cfg="$CODEX_HOME/config.toml"

  # Không overwrite nếu đã có — chỉ merge phần skills
  if [ -f "$cfg" ]; then
    warn "config.toml đã tồn tại — giữ nguyên, chỉ thêm skills mới"
    return 0
  fi

  cat > "$cfg" << 'TOML'
# ~/.codex/config.toml — team-claude-kit

# Model
model = "o4-mini"           # nhanh + rẻ cho daily dev
# model = "o3"              # dùng khi cần reasoning sâu hơn

# Approval policy
# on-request: hỏi trước khi chạy lệnh (khuyến nghị)
# never: auto-approve (chỉ dùng trong CI)
approval_policy = "on-request"

# Sandbox mode
sandbox_mode = "workspace-write"  # cho phép sửa file trong workspace
[sandbox_workspace_write]
network_access = true             # cần cho npm install, git, etc.

# AGENTS.md fallback filenames (nếu project dùng tên khác)
project_doc_fallback_filenames = ["CLAUDE.md", ".agents.md", "TEAM_GUIDE.md"]
project_doc_max_bytes = 65536

# Web search
# web_search = "cached"    # dùng cache (mặc định)
# web_search = "live"      # tìm kiếm thật sự

# TUI
[tui]
notifications = true
notification_method = "auto"

# Skills được load tự động
# (sẽ được append bởi bootstrap.sh)
TOML
}

# ── Append skills vào config.toml ─────────────────────────────────
_append_skill_to_config() {
  local skill_path="$1"
  local cfg="$CODEX_HOME/config.toml"

  # Tránh duplicate
  if grep -qF "path = \"$skill_path\"" "$cfg" 2>/dev/null; then
    return 0
  fi

  cat >> "$cfg" << TOML

[[skills.config]]
path = "$skill_path"
TOML
}

# ── AGENTS.md global ──────────────────────────────────────────────
_write_agents_md() {
  local f="$CODEX_HOME/AGENTS.md"

  # Backup nếu đã có
  if [ -f "$f" ]; then
    cp "$f" "$f.bak"
    warn "Đã backup ~/.codex/AGENTS.md → AGENTS.md.bak"
  fi

  cat > "$f" << 'MD'
# Team Global — Codex Instructions

## Stack
- Runtime: Node.js 20 LTS, pnpm 9+
- Frontend: Next.js 15 (App Router), TypeScript strict, Tailwind 4, shadcn/ui
- Backend: Node.js + Hono/Express, Zod validation
- Database: PostgreSQL + Prisma ORM
- Auth: Auth.js v5

## Working agreements
- Dùng `pnpm` — không dùng npm/yarn
- Chạy `pnpm typecheck && pnpm lint` trước khi commit
- Hỏi trước khi thêm production dependency mới
- Viết test song song với implementation (TDD)
- Không sửa `.env.production`, `prisma/migrations` mà không hỏi

## Code standards
- TypeScript strict — không `any`, không unsafe cast
- Zod cho mọi input validation
- Error: `throw new AppError(code, message, statusCode)`
- Named exports — không default export trừ Next.js pages
- kebab-case files, PascalCase components
- API response: `{ data, error, meta }`

## Before large tasks
1. Đọc AGENTS.md ở project root nếu có
2. Liệt kê files sẽ thay đổi trước khi bắt đầu
3. Hỏi nếu task đụng đến schema DB hoặc API contract

## Hard limits — không làm khi không được phép
- `rm -rf` ngoài thư mục project
- `git push --force` lên main/staging
- DROP TABLE / DROP DATABASE
- Thay đổi .env.production
MD
}

# ── Skills từ ECC (chuyển sang format Codex) ──────────────────────
_install_ecc_skills_for_codex() {
  if [ ! -d "$ECC_DIR" ]; then
    warn "ECC chưa clone. Chạy step ECC trước hoặc: bash bootstrap.sh --target claude"
    return 0
  fi

  # ECC có thư mục skills/ — copy sang ~/.codex/skills/
  local ecc_skills_dirs=(
    "$ECC_DIR/skills"
    "$ECC_DIR/.agents/skills"
  )

  local copied=0
  for skills_dir in "${ecc_skills_dirs[@]}"; do
    [ ! -d "$skills_dir" ] && continue

    for skill_dir in "$skills_dir"/*/; do
      [ ! -d "$skill_dir" ] && continue
      local skill_name; skill_name="$(basename "$skill_dir")"
      local dest="$CODEX_HOME/skills/$skill_name"

      # Copy skill
      run "cp -r '$skill_dir' '$dest'"

      # Tạo SKILL.md nếu chưa có (ECC dùng format khác)
      if [ ! -f "$dest/SKILL.md" ]; then
        _create_skill_md "$dest" "$skill_name"
      fi

      _append_skill_to_config "$dest/SKILL.md"
      ((copied++))
    done
  done

  if [ $copied -gt 0 ]; then
    ok "$copied ECC skills installed → ~/.codex/skills/"
  else
    warn "Không tìm thấy skills trong ECC — kiểm tra $ECC_DIR/skills/"
  fi
}

# ── Skills từ kit (debug, tdd, concurrency, etc.) ─────────────────
_install_kit_skills_for_codex() {
  local kit_skills="$KIT_DIR/claude/skills"
  [ ! -d "$kit_skills" ] && info "Không có kit skills — bỏ qua" && return 0

  local copied=0
  for skill_file in "$kit_skills"/*.md; do
    [ ! -f "$skill_file" ] && continue
    local skill_name; skill_name="$(basename "$skill_file" .md)"
    local dest="$CODEX_HOME/skills/$skill_name"

    run "mkdir -p '$dest'"

    # Claude skills là single .md file — wrap thành Codex skill directory
    _convert_claude_skill_to_codex "$skill_file" "$dest" "$skill_name"
    _append_skill_to_config "$dest/SKILL.md"
    ((copied++))
  done

  ok "$copied kit skills installed → ~/.codex/skills/"
}

# Convert Claude .md skill → Codex SKILL.md directory format
_convert_claude_skill_to_codex() {
  local src="$1" dest="$2" name="$3"

  # Extract description từ frontmatter (dòng description:)
  local desc
  desc=$(grep '^description:' "$src" 2>/dev/null | head -1 | sed 's/^description: *//')
  [ -z "$desc" ] && desc="$name skill"

  # Strip YAML frontmatter, giữ nội dung markdown
  local content
  content=$(awk '/^---/{p++; next} p==2{print}' "$src")
  [ -z "$content" ] && content=$(cat "$src")

  cat > "$dest/SKILL.md" << SKILLMD
# $name

$desc

---

$content
SKILLMD

  # Tạo openai.yaml metadata (cho Codex app UI)
  run "mkdir -p '$dest/agents'"
  cat > "$dest/agents/openai.yaml" << YAML
interface:
  display_name: "$(echo "$name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1))tolower(substr($i,2))}}1')"
  short_description: "$desc"
policy:
  allow_implicit_invocation: true
YAML
}

# Tạo SKILL.md skeleton nếu skill từ ECC không có
_create_skill_md() {
  local dest="$1" name="$2"
  local desc; desc="$(echo "$name" | sed 's/-/ /g')"

  cat > "$dest/SKILL.md" << SKILLMD
# $name

$desc skill from Everything Claude Code.

Use this skill when working on $desc tasks.
SKILLMD
}

# ── MCP servers cho Codex ─────────────────────────────────────────
_setup_codex_mcp() {
  if ! has codex; then
    warn "codex chưa cài — bỏ qua MCP"
    return 0
  fi

  _add_codex_mcp() {
    local name="$1" cmd="$2" desc="$3"
    step "Codex MCP: $name ($desc)"
    if ask "Cài $name?"; then
      local tmp; tmp=$(mktemp)
      if eval "$cmd" > "$tmp" 2>&1; then
        ok "$name added"
      else
        grep -qi "already" "$tmp" 2>/dev/null \
          && info "$name đã có rồi" \
          || { warn "$name failed:"; sed 's/^/    /' "$tmp"; }
      fi
      rm -f "$tmp"
    fi
  }

  _add_codex_mcp "context7" \
    "codex mcp add --transport stdio context7 -- npx -y @upstash/context7-mcp@latest" \
    "live docs lookup"

  _add_codex_mcp "sequential-thinking" \
    "codex mcp add --transport stdio sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking" \
    "multi-step reasoning"

  if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    _add_codex_mcp "github" \
      "codex mcp add --transport stdio github -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server" \
      "GitHub repos/PRs/issues"
  else
    info "GitHub MCP: set GITHUB_PERSONAL_ACCESS_TOKEN rồi chạy lại"
  fi
}

# ── Thêm AGENTS.md vào fallback list nếu chưa có ─────────────────
_patch_codex_config_fallback() {
  local cfg="$CODEX_HOME/config.toml"
  if grep -q 'project_doc_fallback_filenames' "$cfg" 2>/dev/null; then
    info "project_doc_fallback_filenames đã có trong config.toml"
  else
    cat >> "$cfg" << 'TOML'

project_doc_fallback_filenames = ["CLAUDE.md", ".agents.md"]
project_doc_max_bytes = 65536
TOML
    ok "Thêm CLAUDE.md vào fallback filenames"
  fi
}