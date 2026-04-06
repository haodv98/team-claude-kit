#!/usr/bin/env bash
# lib/gitnexus.sh — GitNexus codebase knowledge graph

step_gitnexus() {

  # ── 1. Install ────────────────────────────────────────────────
  section "GitNexus install"

  if has gitnexus; then
    local ver; ver=$(gitnexus --version 2>/dev/null || echo "installed")
    ok "gitnexus already installed ($ver)"
  else
    if ! ask "Cài GitNexus (codebase knowledge graph)?"; then
      info "Bỏ qua GitNexus. Cài sau: npm install -g gitnexus"
      return 0
    fi

    info "Đang cài gitnexus..."
    local tmp; tmp=$(mktemp)

    # macOS thường cần prefix hoặc dùng npx thay vì global install
    if _install_gitnexus "$tmp"; then
      ok "gitnexus installed"
    else
      warn "npm global install failed — thử cách khác..."
      # Fallback: dùng npx wrapper thay vì global
      if _install_gitnexus_npx_wrapper; then
        ok "gitnexus ready (via npx wrapper)"
      else
        warn "GitNexus install failed. Chi tiết:"
        sed 's/^/    /' "$tmp"
        warn "Cài thủ công: npm install -g gitnexus"
        warn "Hoặc nếu lỗi EACCES: sudo npm install -g gitnexus"
        rm -f "$tmp"
        return 1
      fi
    fi
    rm -f "$tmp"
  fi

  # ── 2. Setup MCP ──────────────────────────────────────────────
  section "GitNexus MCP setup"

  if ask "Chạy gitnexus setup (cấu hình MCP cho editors)?"; then
    info "Đang setup MCP..."
    local tmp; tmp=$(mktemp)
    if _run_gitnexus setup > "$tmp" 2>&1; then
      ok "GitNexus MCP configured"
    else
      warn "gitnexus setup failed:"
      sed 's/^/    /' "$tmp"
      warn "Chạy thủ công: gitnexus setup"
    fi
    rm -f "$tmp"
  fi

  # ── 3. Index project hiện tại ─────────────────────────────────
  section "Index project hiện tại"

  local has_project=false
  [ -f "package.json" ] || [ -f "tsconfig.json" ] || [ -d "src" ] && has_project=true

  if [ "$has_project" = false ]; then
    info "Không phát hiện project TypeScript/JS tại $(pwd)"
    info "Chạy sau trong project dir: gitnexus analyze --skills"
    return 0
  fi

  if ask "Index project hiện tại với GitNexus?"; then
    info "Đang index codebase (lần đầu có thể mất vài phút)..."
    local tmp; tmp=$(mktemp)
    if _run_gitnexus analyze --skills > "$tmp" 2>&1; then
      ok "Project indexed → .gitnexus/"
    else
      warn "gitnexus analyze failed:"
      sed 's/^/    /' "$tmp"
      warn "Chạy thủ công: gitnexus analyze --skills"
    fi
    rm -f "$tmp"
  else
    info "Chạy sau: cd $(pwd) && gitnexus analyze --skills"
  fi
}

# ─── Helpers ─────────────────────────────────────────────────────

# Cài gitnexus global — xử lý EACCES trên macOS
_install_gitnexus() {
  local err_file="$1"

  # Thử cài thẳng trước
  if npm install -g gitnexus > "$err_file" 2>&1; then
    return 0
  fi

  # macOS: lỗi EACCES — thử fix npm prefix
  if grep -q "EACCES" "$err_file" 2>/dev/null; then
    warn "npm permission error — thử fix npm prefix..."

    # Option 1: dùng npm prefix trong $HOME (không cần sudo)
    local npm_prefix="$HOME/.npm-global"
    mkdir -p "$npm_prefix"
    npm config set prefix "$npm_prefix" 2>/dev/null

    # Thêm vào PATH nếu chưa có
    local rc="$HOME/.zshrc"
    [ ! -f "$rc" ] && rc="$HOME/.bashrc"
    if ! grep -q "npm-global" "$rc" 2>/dev/null; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$rc"
      export PATH="$HOME/.npm-global/bin:$PATH"
      info "Đã thêm ~/.npm-global/bin vào PATH"
    fi

    npm install -g gitnexus > "$err_file" 2>&1
    return $?
  fi

  return 1
}

# Fallback: tạo wrapper script dùng npx
_install_gitnexus_npx_wrapper() {
  local wrapper="$HOME/.local/bin/gitnexus"
  mkdir -p "$(dirname "$wrapper")"

  cat > "$wrapper" << 'WRAPPER'
#!/usr/bin/env bash
exec npx -y gitnexus@latest "$@"
WRAPPER
  chmod +x "$wrapper"

  # Thêm ~/.local/bin vào PATH nếu chưa có
  local rc="$HOME/.zshrc"
  [ ! -f "$rc" ] && rc="$HOME/.bashrc"
  if ! grep -q '\.local/bin' "$rc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    export PATH="$HOME/.local/bin:$PATH"
  fi

  has gitnexus
}

# Chạy gitnexus — dùng npx làm fallback nếu không có binary
_run_gitnexus() {
  if has gitnexus; then
    gitnexus "$@"
  else
    npx -y gitnexus@latest "$@"
  fi
}