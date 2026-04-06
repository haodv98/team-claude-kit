#!/usr/bin/env bash
# lib/codex.sh — OpenAI Codex CLI setup

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ECC_DIR="$HOME/everything-claude-code"

step_codex() {

  # ── 1. Cài Codex CLI ──────────────────────────────────────────
  section "Codex CLI install"

  if has codex; then
    local ver; ver=$(codex --version 2>/dev/null || echo "installed")
    ok "codex already installed ($ver)"
  else
    if ! ask "Cài Codex CLI (@openai/codex)?"; then
      info "Bỏ qua. Cài sau: npm install -g @openai/codex"
      return 0
    fi
    info "Đang cài @openai/codex..."
    local tmp; tmp=$(mktemp)
    if npm install -g @openai/codex > "$tmp" 2>&1; then
      ok "Codex CLI installed"
    else
      warn "npm install failed:"
      sed 's/^/    /' "$tmp"
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
  fi

  # ── 2. Tạo ~/.codex/ ──────────────────────────────────────────
  section "Codex config directory"
  run "mkdir -p '$CODEX_HOME/skills'"
  ok "~/.codex/ ready"

  # ── 3. config.toml ────────────────────────────────────────────
  section "config.toml"
  if _write_codex_config; then
    ok "~/.codex/config.toml written"
  fi

  # ── 4. AGENTS.md global ───────────────────────────────────────
  section "Global AGENTS.md"
  if _write_agents_md; then
    ok "~/.codex/AGENTS.md written"
  fi

  # ── 5. Skills từ ECC ──────────────────────────────────────────
  section "Skills từ ECC"
  _install_ecc_skills_for_codex

  # ── 6. Skills từ kit ─────────────────────────────────────────
  section "Skills từ team-claude-kit"
  _install_kit_skills_for_codex

  # ── 7. MCP servers ────────────────────────────────────────────
  section "MCP servers"
  _setup_codex_mcp

  # ── 8. Patch config fallback ──────────────────────────────────
  section "Config fallback filenames"
  _patch_codex_config_fallback
  ok "Codex setup hoàn tất"
}

# ─── config.toml ──────────────────────────────────────────────────
_write_codex_config() {
  local cfg="$CODEX_HOME/config.toml"

  if [ -f "$cfg" ]; then
    warn "config.toml đã tồn tại — giữ nguyên (đã backup ở bước trước)"
    return 0
  fi

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $cfg"; return 0; }

  cat > "$cfg" << 'TOML'
# ~/.codex/config.toml — team-claude-kit

model             = "o4-mini"
approval_policy   = "on-request"
sandbox_mode      = "workspace-write"

[sandbox_workspace_write]
network_access = true

project_doc_fallback_filenames = ["CLAUDE.md", ".agents.md", "TEAM_GUIDE.md"]
project_doc_max_bytes          = 65536

[tui]
notifications       = true
notification_method = "auto"
TOML
}

# ─── AGENTS.md global ─────────────────────────────────────────────
_write_agents_md() {
  local f="$CODEX_HOME/AGENTS.md"

  if [ -f "$f" ]; then
    warn "AGENTS.md đã tồn tại — giữ nguyên (đã backup ở bước trước)"
    return 0
  fi

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $f"; return 0; }

  cat > "$f" << 'MD'
# Team Global — Codex Instructions

## Stack
- Runtime: Node.js 20 LTS, pnpm 9+
- Frontend: Next.js 15, TypeScript strict, Tailwind 4, shadcn/ui
- Backend: Node.js + Hono/Express, Zod validation
- Database: PostgreSQL + Prisma ORM
- Auth: Auth.js v5

## Working agreements
- Dùng `pnpm` — không dùng npm/yarn
- Chạy `pnpm typecheck && pnpm lint` trước khi commit
- Hỏi trước khi thêm production dependency mới
- Viết test song song với implementation (TDD)

## Code standards
- TypeScript strict — không `any`, không unsafe cast
- Zod cho mọi input validation
- Error: `throw new AppError(code, message, statusCode)`
- Named exports, kebab-case files, PascalCase components
- API response: `{ data, error, meta }`

## Hard limits — không làm khi không được phép
- `rm -rf` ngoài thư mục project
- `git push --force` lên main/staging
- DROP TABLE / DROP DATABASE
- Thay đổi .env.production hoặc prisma/migrations
MD
}

# ─── Skills từ ECC ────────────────────────────────────────────────
_install_ecc_skills_for_codex() {
  if [ ! -d "$ECC_DIR" ]; then
    warn "ECC chưa clone — bỏ qua ECC skills"
    info "Chạy trước: bash bootstrap.sh --target claude"
    return 0
  fi

  local copied=0
  for skills_dir in "$ECC_DIR/skills" "$ECC_DIR/.agents/skills"; do
    [ ! -d "$skills_dir" ] && continue
    for skill_dir in "$skills_dir"/*/; do
      [ ! -d "$skill_dir" ] && continue
      local skill_name; skill_name="$(basename "$skill_dir")"
      local dest="$CODEX_HOME/skills/$skill_name"
      [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] copy $skill_name"; ((copied++)); continue; }
      cp -r "$skill_dir" "$dest" 2>/dev/null || true
      [ ! -f "$dest/SKILL.md" ] && _create_skill_md "$dest" "$skill_name"
      _append_skill_to_config "$dest/SKILL.md"
      ((copied++)) || true
    done
  done

  [ $copied -gt 0 ] && ok "$copied ECC skills → ~/.codex/skills/" \
                    || warn "Không tìm thấy skills trong ECC"
}

# ─── Skills từ kit ────────────────────────────────────────────────
_install_kit_skills_for_codex() {
  local kit_skills="$SCRIPT_DIR/claude/skills"
  if [ ! -d "$kit_skills" ]; then
    info "Không có kit skills — bỏ qua"
    return 0
  fi

  local copied=0
  for skill_file in "$kit_skills"/*.md; do
    [ ! -f "$skill_file" ] && continue
    local skill_name; skill_name="$(basename "$skill_file" .md)"
    local dest="$CODEX_HOME/skills/$skill_name"
    [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] convert $skill_name"; ((copied++)); continue; }
    mkdir -p "$dest"
    _convert_claude_skill_to_codex "$skill_file" "$dest" "$skill_name"
    _append_skill_to_config "$dest/SKILL.md"
    ((copied++)) || true
  done

  [ $copied -gt 0 ] && ok "$copied kit skills → ~/.codex/skills/" \
                    || info "Không có kit skills để copy"
}

# ─── MCP servers ──────────────────────────────────────────────────
_setup_codex_mcp() {
  if ! has codex; then
    warn "codex chưa cài — bỏ qua MCP"
    return 0
  fi

  _add_codex_mcp() {
    local name="$1" cmd="$2" desc="$3"
    if ask "Cài MCP: $name ($desc)?"; then
      info "Đang thêm $name..."
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
    "codex mcp add stdio context7 -- npx -y @upstash/context7-mcp@latest" \
    "live docs lookup"

  _add_codex_mcp "sequential-thinking" \
    "codex mcp add stdio sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking" \
    "multi-step reasoning"

  if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    _add_codex_mcp "github" \
      "codex mcp add --transport stdio github -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server" \
      "GitHub repos/PRs/issues"
  else
    info "GitHub MCP: export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_...' rồi chạy lại"
  fi
}

# ─── Helpers ──────────────────────────────────────────────────────
_append_skill_to_config() {
  local skill_path="$1"
  local cfg="$CODEX_HOME/config.toml"
  grep -qF "path = \"$skill_path\"" "$cfg" 2>/dev/null && return 0
  printf '\n[[skills.config]]\npath = "%s"\n' "$skill_path" >> "$cfg"
}

_convert_claude_skill_to_codex() {
  local src="$1" dest="$2" name="$3"
  local desc; desc=$(grep '^description:' "$src" 2>/dev/null | head -1 | sed 's/^description: *//')
  [ -z "$desc" ] && desc="$name skill"
  local content; content=$(awk '/^---/{p++; next} p==2{print}' "$src")
  [ -z "$content" ] && content=$(cat "$src")
  printf '# %s\n\n%s\n\n---\n\n%s\n' "$name" "$desc" "$content" > "$dest/SKILL.md"
  mkdir -p "$dest/agents"
  printf 'interface:\n  display_name: "%s"\n  short_description: "%s"\npolicy:\n  allow_implicit_invocation: true\n' \
    "$name" "$desc" > "$dest/agents/openai.yaml"
}

_create_skill_md() {
  local dest="$1" name="$2"
  printf '# %s\n\n%s skill from Everything Claude Code.\n' \
    "$name" "$(echo "$name" | sed 's/-/ /g')" > "$dest/SKILL.md"
}

_patch_codex_config_fallback() {
  local cfg="$CODEX_HOME/config.toml"
  grep -q 'project_doc_fallback_filenames' "$cfg" 2>/dev/null \
    && info "Fallback filenames đã có trong config.toml" \
    || { printf '\nproject_doc_fallback_filenames = ["CLAUDE.md", ".agents.md"]\n' >> "$cfg"
         ok "Thêm CLAUDE.md vào fallback filenames"; }
}