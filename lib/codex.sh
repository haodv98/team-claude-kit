#!/usr/bin/env bash
# lib/codex.sh — OpenAI Codex CLI setup
# Dùng script chính thức của ECC: scripts/sync-ecc-to-codex.sh

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
      warn "npm install failed:"; sed 's/^/    /' "$tmp"
      rm -f "$tmp"; return 1
    fi
    rm -f "$tmp"
  fi

  # ── 2. Cần ECC đã clone ───────────────────────────────────────
  section "Kiểm tra ECC"

  if [ ! -d "$ECC_DIR" ]; then
    warn "ECC chưa clone tại $ECC_DIR"
    if ask "Clone ECC ngay bây giờ?"; then
      info "Cloning everything-claude-code..."
      local tmp; tmp=$(mktemp)
      if git clone --depth=1 \
          https://github.com/affaan-m/everything-claude-code.git \
          "$ECC_DIR" > "$tmp" 2>&1; then
        ok "ECC cloned → $ECC_DIR"
      else
        warn "Clone failed:"; sed 's/^/    /' "$tmp"
        rm -f "$tmp"; return 1
      fi
      rm -f "$tmp"
    else
      warn "Cần ECC để sync Codex. Chạy trước: bash bootstrap.sh --target claude"
      return 1
    fi
  else
    ok "ECC found at $ECC_DIR"
  fi

  # ── 3. npm install trong ECC (sync script cần dependencies) ───
  section "ECC dependencies"

  local pkg_manager="npm"
  has pnpm && pkg_manager="pnpm"
  has bun  && pkg_manager="bun"

  info "Cài ECC dependencies (${pkg_manager} install)..."
  local tmp; tmp=$(mktemp)
  if (cd "$ECC_DIR" && $pkg_manager install --silent) > "$tmp" 2>&1; then
    ok "Dependencies installed (${pkg_manager})"
  else
    warn "${pkg_manager} install failed:"; sed 's/^/    /' "$tmp"
    rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"

  # ── 4. Chạy sync-ecc-to-codex.sh ─────────────────────────────
  section "Sync ECC → Codex (agents, skills, commands, MCP)"

  local sync_script="$ECC_DIR/scripts/sync-ecc-to-codex.sh"

  if [ ! -f "$sync_script" ]; then
    warn "sync-ecc-to-codex.sh không tìm thấy tại $sync_script"
    warn "ECC version này có thể chưa hỗ trợ Codex sync"
    info "Thử cập nhật ECC: cd $ECC_DIR && git pull"
    _codex_manual_fallback
    return 0
  fi

  info "Chạy scripts/sync-ecc-to-codex.sh..."
  local tmp; tmp=$(mktemp)

  # Dry-run mode
  if [ "${DRY_RUN:-false}" = true ]; then
    info "[dry-run] bash $sync_script --dry-run"
    rm -f "$tmp"; return 0
  fi

  if (cd "$ECC_DIR" && bash "$sync_script") > "$tmp" 2>&1; then
    ok "ECC synced to ~/.codex"
    # In summary từ script (thường có ✓ lines)
    grep -E '(✓|✗|→|synced|copied|skipped)' "$tmp" 2>/dev/null \
      | head -20 | sed 's/^/    /' || true
  else
    warn "sync-ecc-to-codex.sh failed:"; sed 's/^/    /' "$tmp"
    rm -f "$tmp"
    warn "Thử fallback manual copy..."
    _codex_manual_fallback
    return 0
  fi
  rm -f "$tmp"

  # ── 5. Patch config.toml nếu chưa có ─────────────────────────
  section "Patch config.toml"
  _ensure_codex_config

  # ── 6. MCP servers bổ sung ───────────────────────────────────
  section "MCP servers bổ sung"
  _setup_codex_extra_mcp

  ok "Codex setup hoàn tất"
  _print_codex_next_steps
}

# ─── Fallback: manual copy nếu sync script không có/fail ─────────
_codex_manual_fallback() {
  info "Fallback: manual copy từ ECC..."
  mkdir -p "$CODEX_HOME/skills"

  # AGENTS.md
  local agents_src="$ECC_DIR/.codex/AGENTS.md"
  if [ -f "$agents_src" ]; then
    cp "$agents_src" "$CODEX_HOME/AGENTS.md"
    ok "AGENTS.md copied"
  fi

  # config.toml
  local cfg_src="$ECC_DIR/.codex/config.toml"
  if [ -f "$cfg_src" ] && [ ! -f "$CODEX_HOME/config.toml" ]; then
    cp "$cfg_src" "$CODEX_HOME/config.toml"
    ok "config.toml copied"
  fi

  # Skills
  local copied=0
  for d in "$ECC_DIR/skills"/*/ "$ECC_DIR/.agents/skills"/*/; do
    [ -d "$d" ] || continue
    local name; name=$(basename "$d")
    cp -r "$d" "$CODEX_HOME/skills/$name" 2>/dev/null && ((copied++)) || true
  done
  [ $copied -gt 0 ] && ok "$copied skills copied → ~/.codex/skills/"

  _ensure_codex_config
}

# ─── Đảm bảo config.toml có các field cần thiết ──────────────────
_ensure_codex_config() {
  local cfg="$CODEX_HOME/config.toml"
  mkdir -p "$CODEX_HOME"

  # Tạo mới nếu chưa có
  if [ ! -f "$cfg" ]; then
    cat > "$cfg" << 'TOML'
# ~/.codex/config.toml — team-claude-kit

model           = "o4-mini"
approval_policy = "on-request"
sandbox_mode    = "workspace-write"

[sandbox_workspace_write]
network_access = true

# AGENTS.md fallback: đọc CLAUDE.md nếu không có AGENTS.md
project_doc_fallback_filenames = ["CLAUDE.md", ".agents.md", "TEAM_GUIDE.md"]
project_doc_max_bytes          = 65536

[tui]
notifications       = true
notification_method = "auto"

# Codex không hỗ trợ hooks — dùng persistent_instructions thay thế
[persistent_instructions]
instructions = """
SECURITY (không được phép):
- Không rm -rf ngoài thư mục project
- Không git push --force lên main/staging
- Không DROP TABLE/DATABASE
- Không thay đổi .env.production
- Không cài package mà không hỏi

CODE STANDARDS:
- TypeScript strict, không dùng any
- Zod cho input validation
- pnpm, không dùng npm/yarn
- Chạy pnpm typecheck && pnpm lint trước khi commit
"""
TOML
    ok "config.toml created"
    return 0
  fi

  # Patch fallback filenames nếu chưa có
  if ! grep -q 'project_doc_fallback_filenames' "$cfg" 2>/dev/null; then
    printf '\nproject_doc_fallback_filenames = ["CLAUDE.md", ".agents.md"]\n' >> "$cfg"
    ok "Thêm CLAUDE.md vào fallback filenames"
  fi

  # Patch persistent_instructions nếu chưa có (thay thế hooks)
  if ! grep -q 'persistent_instructions' "$cfg" 2>/dev/null; then
    cat >> "$cfg" << 'TOML'

# Codex không hỗ trợ hooks — persistent_instructions thay thế
[persistent_instructions]
instructions = """
SECURITY: không rm -rf, không git push --force, không DROP TABLE,
không thay đổi .env.production, hỏi trước khi cài package mới.
CODE: TypeScript strict, Zod validation, pnpm, typecheck+lint trước commit.
"""
TOML
    ok "Thêm persistent_instructions (thay thế hooks)"
  fi

  info "config.toml đã có — giữ nguyên (đã backup ở bước trước)"
}

# ─── MCP servers bổ sung (ngoài những gì ECC sync) ───────────────
_setup_codex_extra_mcp() {
  if ! has codex; then
    warn "codex chưa cài — bỏ qua MCP"
    return 0
  fi

  local mcp_json="$CODEX_HOME/mcp.json"
  mkdir -p "$CODEX_HOME"

  # ── Auto-write mcp.json với core MCPs ───────────────────────────
  if [[ ! -f "$mcp_json" ]]; then
    cat > "$mcp_json" << 'JSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking@latest"]
    }
  }
}
JSON
    ok "mcp.json created (context7 + sequential-thinking)"
  else
    ok "mcp.json đã có — giữ nguyên"
  fi

  # ── Thêm Backlog nếu có credentials ─────────────────────────────
  if [[ -n "${BACKLOG_DOMAIN:-}" && -n "${BACKLOG_API_KEY:-}" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      BACKLOG_DOMAIN="$BACKLOG_DOMAIN" BACKLOG_API_KEY="$BACKLOG_API_KEY" \
      MCP_JSON_PATH="$mcp_json" python3 -c "
import json, os
path = os.environ['MCP_JSON_PATH']
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault('mcpServers', {})['backlog'] = {
    'command': 'npx',
    'args': ['-y', 'backlog-mcp-server@latest'],
    'env': {
        'BACKLOG_DOMAIN': os.environ['BACKLOG_DOMAIN'],
        'BACKLOG_API_KEY': os.environ['BACKLOG_API_KEY']
    }
}
with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null && ok "Backlog MCP added to mcp.json" || \
        warn "Backlog MCP: thêm thủ công vào $mcp_json"
    else
      warn "python3 không có — thêm Backlog MCP thủ công vào $mcp_json"
    fi
  else
    info "Backlog MCP: thiếu BACKLOG_DOMAIN/BACKLOG_API_KEY — bỏ qua"
  fi

  # ── Interactive: Sentry + Figma (HTTP transport) ─────────────────
  _add_mcp_http() {
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

  if [[ -n "${SENTRY_TOKEN:-}" ]]; then
    _add_mcp_http "sentry" \
      "codex mcp add --transport http sentry https://mcp.sentry.dev/mcp --header 'Authorization: Bearer $SENTRY_TOKEN'" \
      "production error debugging"
  else
    info "Sentry MCP: export SENTRY_TOKEN='sntrys_...' rồi chạy lại"
  fi

  if [[ -n "${FIGMA_TOKEN:-}" ]]; then
    _add_mcp_http "figma" \
      "codex mcp add --transport http figma https://mcp.figma.com/mcp --header 'Authorization: Bearer $FIGMA_TOKEN'" \
      "design to code"
  else
    info "Figma MCP: export FIGMA_TOKEN='figd_...' rồi chạy lại"
  fi
}

# ─── Next steps sau khi setup ────────────────────────────────────
_print_codex_next_steps() {
  _tty ""
  _tty "  ${CYAN}Codex CLI sẵn sàng. Cách dùng:${NC}"
  _tty "    codex                              ${DIM}# interactive TUI${NC}"
  _tty "    codex --full-auto \"<task>\"         ${DIM}# auto mode${NC}"
  _tty "    codex --profile fast \"<task>\"      ${DIM}# nhanh hơn${NC}"
  _tty ""
  _tty "  ${YELLOW}Lưu ý: Codex chưa hỗ trợ hooks${NC}"
  _tty "  ${DIM}Security enforcement dùng persistent_instructions trong config.toml${NC}"
}