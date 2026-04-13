#!/usr/bin/env bash
# lib/mcp.sh — Cài đặt MCP servers cho Claude Code
#
# Cần trong .env.local:
#   BACKLOG_DOMAIN=yourspace.backlog.com
#   BACKLOG_API_KEY=abcdefghijklmn

step_mcp() {
  info "Cài MCP servers..."

  # Load .env.local nếu chưa có trong môi trường
  # (step_mcp chạy trong subshell của run_step nên cần load lại)
  local env_file="$SCRIPT_DIR/.env.local"
  if [[ -f "$env_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      local key="${line%%=*}"
      [[ -z "${!key:-}" ]] && export "$line"
    done < "$env_file"
  fi

  _mcp_add_context7
  _mcp_add_sequential_thinking
  _mcp_add_github
  _mcp_add_sentry
  _mcp_add_figma
  _mcp_add_backlog    # [MỚI] Backlog MCP
}

# ─── Helpers ─────────────────────────────────────────────────────
_mcp_install() {
  local name="$1"; shift
  if claude mcp list 2>/dev/null | grep -q "^$name"; then
    info "MCP '$name' đã có — skip"
    return 0
  fi
  run claude mcp add "$@"
  ok "MCP '$name' đã cài"
}

# ─── Individual MCP servers ──────────────────────────────────────
_mcp_add_context7() {
  _mcp_install "context7" \
    --scope user --transport stdio context7 \
    -- npx -y @upstash/context7-mcp@latest
}

_mcp_add_sequential_thinking() {
  _mcp_install "sequential-thinking" \
    --scope user --transport stdio sequential-thinking \
    -- npx -y @modelcontextprotocol/server-sequential-thinking
}

_mcp_add_github() {
  if [[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    warn "GITHUB_PERSONAL_ACCESS_TOKEN chưa set — skip GitHub MCP"
    return 0
  fi
  _mcp_install "github" \
    --scope user --transport stdio github \
    -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
    -- docker run -i --rm \
      -e GITHUB_PERSONAL_ACCESS_TOKEN \
      ghcr.io/github/github-mcp-server
}

_mcp_add_sentry() {
  if [[ -z "${SENTRY_TOKEN:-}" ]]; then
    warn "SENTRY_TOKEN chưa set — skip Sentry MCP"
    return 0
  fi
  _mcp_install "sentry" \
    --scope user --transport stdio sentry \
    -e SENTRY_TOKEN="$SENTRY_TOKEN" \
    -- npx -y @sentry/mcp-server@latest
}

_mcp_add_figma() {
  if [[ -z "${FIGMA_TOKEN:-}" ]]; then
    warn "FIGMA_TOKEN chưa set — skip Figma MCP"
    return 0
  fi
  _mcp_install "figma" \
    --scope user --transport stdio figma \
    -e FIGMA_TOKEN="$FIGMA_TOKEN" \
    -- npx -y @figma/mcp-server@latest
}

# ─── [MỚI] Backlog MCP Server ────────────────────────────────────
_mcp_add_backlog() {
  if [[ -z "${BACKLOG_DOMAIN:-}" || -z "${BACKLOG_API_KEY:-}" ]]; then
    warn "BACKLOG_DOMAIN hoặc BACKLOG_API_KEY chưa set — skip Backlog MCP"
    warn "Thêm vào .env.local rồi chạy lại: bash bootstrap.sh --yes"
    return 0
  fi

  _mcp_install "backlog" \
    --scope user --transport stdio backlog \
    -e BACKLOG_DOMAIN="$BACKLOG_DOMAIN" \
    -e BACKLOG_API_KEY="$BACKLOG_API_KEY" \
    -e ENABLE_TOOLSETS="space,project,issue,git,notifications" \
    -e OPTIMIZE_RESPONSE=1 \
    -e MAX_TOKENS=20000 \
    -- npx -y backlog-mcp-server
}

# ─── Reinstall một MCP cụ thể ────────────────────────────────────
mcp_reinstall_backlog() {
  info "Reinstall Backlog MCP..."
  run claude mcp remove backlog 2>/dev/null || true
  _mcp_add_backlog
}