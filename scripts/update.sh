#!/usr/bin/env bash
# scripts/update.sh — Full kit update: ECC + MCP servers + graphify + playbook
#
# Gọi qua alias: ccupdate

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

header "team-claude-kit update"

ERRORS=0

# ─── 1. ECC update ───────────────────────────────────────────────
section "ECC (Everything Claude Code)"

ECC_DIR="$HOME/everything-claude-code"
if [[ -d "$ECC_DIR" ]]; then
  info "Pulling latest ECC..."
  git -C "$ECC_DIR" pull --quiet 2>/dev/null && ok "ECC pulled" || \
    { warn "ECC pull failed (offline?)"; ERRORS=$(( ERRORS + 1 )); }

  # Detect target from .ecc-version or shell config
  TARGET="${TARGET:-claude}"
  LANGUAGES="${LANGUAGES:-typescript}"

  info "Running ECC install (target=$TARGET, langs=$LANGUAGES)..."
  if bash "$ECC_DIR/install.sh" --target "$TARGET" "$LANGUAGES" 2>/dev/null; then
    ok "ECC install → ~/.claude"
  else
    warn "ECC install failed — chạy thủ công: bash ~/everything-claude-code/install.sh"
    ERRORS=$(( ERRORS + 1 ))
  fi
else
  warn "ECC chưa clone tại $ECC_DIR — bỏ qua"
  ERRORS=$(( ERRORS + 1 ))
fi

# ─── 2. ccg-workflow ─────────────────────────────────────────────
section "ccg-workflow"

if command -v npm >/dev/null 2>&1; then
  npm update -g ccg-workflow --quiet 2>/dev/null && ok "ccg-workflow updated" || \
    info "ccg-workflow không cài toàn cục — bỏ qua"
fi

# ─── 3. Graphify ─────────────────────────────────────────────────
section "Graphify"

if command -v pip3 >/dev/null 2>&1; then
  pip3 install --upgrade graphifyy --quiet \
    --break-system-packages 2>/dev/null && ok "graphify updated" || \
    { warn "graphify update failed — thử: pip3 install --upgrade graphifyy"; \
      ERRORS=$(( ERRORS + 1 )); }
elif command -v pip >/dev/null 2>&1; then
  pip install --upgrade graphifyy --quiet 2>/dev/null && ok "graphify updated" || \
    warn "graphify update failed"
else
  warn "pip không có — bỏ qua graphify update"
fi

# ─── 4. MCP servers ──────────────────────────────────────────────
section "MCP servers"

if command -v claude >/dev/null 2>&1; then
  # Load env để lấy BACKLOG_DOMAIN, BACKLOG_API_KEY
  [ -f "$SCRIPT_DIR/.env.local" ] && source "$SCRIPT_DIR/.env.local"

  # Refresh backlog MCP (xóa và cài lại để cập nhật version)
  if [[ -n "${BACKLOG_DOMAIN:-}" && -n "${BACKLOG_API_KEY:-}" ]]; then
    info "Refreshing backlog MCP..."
    claude mcp remove backlog 2>/dev/null || true
    claude mcp add --transport stdio backlog \
      npx -- -y backlog-mcp-server@latest \
      --env BACKLOG_DOMAIN="$BACKLOG_DOMAIN" \
      --env BACKLOG_API_KEY="$BACKLOG_API_KEY" \
      2>/dev/null && ok "backlog MCP refreshed" || \
      warn "backlog MCP refresh failed — kiểm tra BACKLOG_DOMAIN/BACKLOG_API_KEY"
  else
    info "Backlog MCP: thiếu BACKLOG_DOMAIN/BACKLOG_API_KEY — bỏ qua"
  fi

  ok "MCP update hoàn tất"
else
  warn "claude CLI không có — bỏ qua MCP update"
fi

# ─── 5. Playbook sync ────────────────────────────────────────────
section "Playbook sync"

if git -C "$SCRIPT_DIR" remote get-url origin >/dev/null 2>&1; then
  info "Pulling kit updates from remote..."
  git -C "$SCRIPT_DIR" pull --quiet 2>/dev/null && ok "Kit synced from remote" || \
    warn "Sync failed (offline hoặc có local changes)"
else
  info "Không có git remote — bỏ qua playbook sync"
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
if [[ "$ERRORS" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✅ Update hoàn tất${RESET}"
else
  echo -e "${YELLOW}${BOLD}⚠️  Update xong với $ERRORS cảnh báo${RESET}"
  echo "   Chạy cchealth để kiểm tra chi tiết"
fi
echo "────────────────────────────────────────────────"
echo ""
