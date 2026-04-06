#!/usr/bin/env bash
# lib/mcp.sh — MCP servers (chỉ áp dụng khi target=claude)

step_mcp() {
  if [ "$TARGET" != "claude" ]; then
    info "Target=$TARGET — bỏ qua MCP setup (chỉ dành cho claude)"
    return 0
  fi

  if ! has claude; then
    warn "Claude Code chưa cài — bỏ qua MCP"
    info "Sau khi cài, chạy lại: bash bootstrap.sh --target claude --languages \"$LANGUAGES\""
    return 0
  fi

  # Helper ────────────────────────────────────────────────────────
  add_mcp() {
    local name="$1" cmd="$2" desc="$3"
    step "MCP: $name ($desc)"
    if ask "Cài $name?"; then
      local tmp; tmp=$(mktemp)
      if eval "$cmd" > "$tmp" 2>&1; then
        ok "$name added"
      else
        if grep -qi "already" "$tmp" 2>/dev/null; then
          info "$name đã cài rồi — bỏ qua"
        else
          warn "$name failed:"
          sed 's/^/    /' "$tmp"   # indent error output
        fi
      fi
      rm -f "$tmp"
    fi
  }

  add_mcp "context7" \
    "claude mcp add --scope user stdio context7 -- npx -y @upstash/context7-mcp@latest" \
    "live docs, giảm hallucinate"

  add_mcp "sequential-thinking" \
    "claude mcp add --scope user stdio sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking" \
    "multi-step reasoning"

  # GitHub — cần token
  step "MCP: github"
  if ask "Cài GitHub MCP?"; then
    if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
      warn "GITHUB_PERSONAL_ACCESS_TOKEN chưa set"
      info "Thêm vào ~/.zshrc rồi chạy lại:"
      info "  export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_...'"
    else
      local tmp; tmp=$(mktemp)
      if claude mcp add --scope user --transport stdio github \
          -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN \
          ghcr.io/github/github-mcp-server > "$tmp" 2>&1; then
        ok "github MCP added"
      else
        warn "github MCP failed:"; sed 's/^/    /' "$tmp"
      fi
      rm -f "$tmp"
    fi
  fi

  # Sentry — cần token
  step "MCP: sentry"
  if ask "Cài Sentry MCP?"; then
    if [ -z "${SENTRY_TOKEN:-}" ]; then
      warn "SENTRY_TOKEN chưa set"
      info "  export SENTRY_TOKEN='sntrys_...'"
    else
      local tmp; tmp=$(mktemp)
      if claude mcp add --scope user --transport http sentry \
          https://mcp.sentry.dev/mcp \
          --header "Authorization: Bearer $SENTRY_TOKEN" > "$tmp" 2>&1; then
        ok "sentry MCP added"
      else
        warn "sentry MCP failed:"; sed 's/^/    /' "$tmp"
      fi
      rm -f "$tmp"
    fi
  fi

  # Figma — cần token
  step "MCP: figma"
  if ask "Cài Figma MCP?"; then
    if [ -z "${FIGMA_TOKEN:-}" ]; then
      warn "FIGMA_TOKEN chưa set"
      info "  export FIGMA_TOKEN='figd_...'"
    else
      local tmp; tmp=$(mktemp)
      if claude mcp add --scope user --transport http figma \
          https://mcp.figma.com/mcp \
          --header "Authorization: Bearer $FIGMA_TOKEN" > "$tmp" 2>&1; then
        ok "figma MCP added"
      else
        warn "figma MCP failed:"; sed 's/^/    /' "$tmp"
      fi
      rm -f "$tmp"
    fi
  fi

  info "Kiểm tra MCP: /mcp trong Claude Code session"
}