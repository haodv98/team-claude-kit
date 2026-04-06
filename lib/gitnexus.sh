#!/usr/bin/env bash
# lib/gitnexus.sh — GitNexus codebase knowledge graph

step_gitnexus() {
  # ── Install ────────────────────────────────────────────────────
  step "GitNexus install"
  if has gitnexus; then
    ok "gitnexus already installed"
  else
    if run "npm install -g gitnexus"; then
      ok "gitnexus installed"
    else
      warn "npm install -g gitnexus failed"
      info "Thử: sudo npm install -g gitnexus"
      return 1
    fi
  fi

  # ── Setup MCP ─────────────────────────────────────────────────
  step "GitNexus MCP setup"
  if ask "Chạy gitnexus setup (configure MCP cho editors)?"; then
    local tmp; tmp=$(mktemp)
    if run "gitnexus setup" > "$tmp" 2>&1; then
      ok "gitnexus MCP configured"
    else
      warn "gitnexus setup failed:"
      sed 's/^/    /' "$tmp"
    fi
    rm -f "$tmp"
  fi

  # ── Index current project (nếu đang ở trong project) ──────────
  step "GitNexus: index current project"
  if [ -f "package.json" ] || [ -f "tsconfig.json" ] || [ -d "src" ]; then
    if ask "Index project hiện tại?"; then
      local tmp; tmp=$(mktemp)
      info "Indexing (lần đầu có thể mất vài phút)..."
      if run "gitnexus analyze --skills" > "$tmp" 2>&1; then
        ok "Project indexed → .gitnexus/"
      else
        warn "gitnexus analyze failed:"
        sed 's/^/    /' "$tmp"
      fi
      rm -f "$tmp"
    fi
  else
    info "Không phát hiện project TypeScript/JS ở thư mục hiện tại"
    info "Chạy sau trong project dir: gitnexus analyze --skills"
  fi
}