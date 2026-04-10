#!/usr/bin/env bash
# scripts/cchealth.sh — Health check toàn bộ team-claude-kit
# Alias: cchealth

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }
section() { echo -e "\n${BOLD}${BLUE}▸ $1${RESET}"; }

ISSUES=0

# ─── 1. Dependencies ─────────────────────────────────────────────
section "Dependencies"

check_cmd() {
  local cmd="$1" label="${2:-$1}" min_ver="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver="$($cmd --version 2>&1 | head -1)"
    ok "$label — $ver"
  else
    fail "$label — không tìm thấy"
    ((ISSUES++))
  fi
}

check_cmd git   "git"
check_cmd node  "node"
check_cmd npm   "npm"
check_cmd claude "claude CLI"
command -v docker >/dev/null 2>&1 \
  && ok "docker — $(docker --version 2>&1 | head -1)" \
  || warn "docker — không có (GitHub MCP sẽ không dùng được)"

# Node version
if command -v node >/dev/null 2>&1; then
  node_major=$(node -e "console.log(parseInt(process.versions.node))")
  if [[ "$node_major" -ge 18 ]]; then
    ok "node v$node_major >= 18"
  else
    fail "node v$node_major — cần v18+"
    ((ISSUES++))
  fi
fi

# ─── 2. ECC ──────────────────────────────────────────────────────
section "Everything Claude Code (ECC)"

ECC_DIR="$HOME/everything-claude-code"
ECC_VERSION_FILE="$SCRIPT_DIR/.ecc-version"

if [[ -d "$ECC_DIR" ]]; then
  local_commit="$(git -C "$ECC_DIR" rev-parse HEAD 2>/dev/null | cut -c1-8)"
  ok "ECC installed — commit $local_commit"

  # Check có update không (offline-safe)
  git -C "$ECC_DIR" fetch origin --quiet 2>/dev/null || true
  remote="$(git -C "$ECC_DIR" rev-parse origin/main 2>/dev/null | cut -c1-8 || echo "unknown")"
  if [[ "$local_commit" != "$remote" && "$remote" != "unknown" ]]; then
    warn "ECC có update: local=$local_commit remote=$remote → chạy ccupdate"
  else
    ok "ECC up to date"
  fi

  if [[ -f "$ECC_VERSION_FILE" ]]; then
    ok "Version pinned: $(cat "$ECC_VERSION_FILE" | cut -c1-8)"
  else
    warn ".ecc-version chưa có — chạy bootstrap để pin"
  fi
else
  fail "ECC chưa được cài ($ECC_DIR không tồn tại)"
  ((ISSUES++))
fi

# ─── 3. MCP Servers ──────────────────────────────────────────────
section "MCP Servers"

if command -v claude >/dev/null 2>&1; then
  mcp_list="$(claude mcp list 2>/dev/null || echo "")"
  expected_mcps=("context7" "sequential-thinking" "github" "sentry" "figma")

  for mcp in "${expected_mcps[@]}"; do
    if echo "$mcp_list" | grep -q "$mcp"; then
      ok "$mcp — connected"
    else
      warn "$mcp — không tìm thấy"
    fi
  done
else
  warn "claude CLI không có — không thể check MCP"
fi

# ─── 4. Secrets / API Keys ───────────────────────────────────────
section "API Keys"

check_token() {
  local var="$1" label="$2"
  local env_file="$SCRIPT_DIR/.env.local"

  # Check env var trực tiếp
  if [[ -n "${!var:-}" ]]; then
    ok "$label — set (từ môi trường)"
    return
  fi

  # Check trong .env.local
  if [[ -f "$env_file" ]] && grep -q "^$var=" "$env_file" 2>/dev/null; then
    ok "$label — set (từ .env.local)"
    return
  fi

  # Check macOS Keychain
  if [[ "$(uname)" == "Darwin" ]]; then
    local val
    val="$(security find-generic-password -a "$USER" -s "team-claude-kit-$var" -w 2>/dev/null || echo "")"
    if [[ -n "$val" ]]; then
      ok "$label — set (từ Keychain)"
      return
    fi
  fi

  warn "$label — chưa set (chạy: bash scripts/setup-secrets.sh)"
}

check_token "GITHUB_PERSONAL_ACCESS_TOKEN" "GitHub Token"
check_token "SENTRY_TOKEN"                  "Sentry Token"
check_token "FIGMA_TOKEN"                   "Figma Token"

# Cảnh báo nếu token nằm trong shell RC files (anti-pattern)
for rc_file in ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile; do
  if [[ -f "$rc_file" ]]; then
    for var in GITHUB_PERSONAL_ACCESS_TOKEN SENTRY_TOKEN FIGMA_TOKEN; do
      if grep -q "export $var=" "$rc_file" 2>/dev/null; then
        fail "⚠️  $var đang được export plaintext trong $rc_file — không an toàn!"
        ((ISSUES++))
      fi
    done
  fi
done

# ─── 5. Shell aliases ────────────────────────────────────────────
section "Shell Aliases"

aliases_to_check=("ccstart" "cctime" "ccupdate" "ccnew" "cchealth")
for alias_name in "${aliases_to_check[@]}"; do
  if alias "$alias_name" >/dev/null 2>&1 || type "$alias_name" >/dev/null 2>&1; then
    ok "$alias_name — loaded"
  else
    warn "$alias_name — chưa load (chạy: source ${SHELL_RC:-~/.zshrc})"
  fi
done

# ─── 6. Graphify ─────────────────────────────────────────────────
section "Graphify"

if command -v graphify >/dev/null 2>&1; then
  ok "graphify CLI — $(graphify --version 2>/dev/null || echo 'installed')"
else
  warn "graphify CLI — chưa cài (pip install graphifyy)"
  ((ISSUES++))
fi

# Kiểm tra Python 3.10+
if command -v python3 >/dev/null 2>&1; then
  py_ok="$(python3 -c 'import sys; print(1 if sys.version_info >= (3,10) else 0)' 2>/dev/null)"
  if [[ "$py_ok" == "1" ]]; then
    ok "python3 — $(python3 --version)"
  else
    fail "python3 $(python3 --version) — cần 3.10+ cho Graphify"
    ((ISSUES++))
  fi
else
  fail "python3 — không tìm thấy"
  ((ISSUES++))
fi

# Kiểm tra skill file
SKILL_FILE="$HOME/.claude/skills/graphify/SKILL.md"
if [[ -f "$SKILL_FILE" ]]; then
  ok "Graphify skill — $SKILL_FILE"
else
  warn "Graphify skill chưa cài — chạy bootstrap để fix"
fi

# Kiểm tra CLAUDE.md entry
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]] && grep -q "graphify" "$CLAUDE_MD" 2>/dev/null; then
  ok "CLAUDE.md — graphify entry có sẵn"
else
  warn "CLAUDE.md — thiếu graphify entry (chạy bootstrap để fix)"
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
if [[ "$ISSUES" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✅ Tất cả OK — kit sẵn sàng sử dụng${RESET}"
else
  echo -e "${RED}${BOLD}❌ Có $ISSUES vấn đề cần xử lý${RESET}"
  echo "   Chạy lại sau khi fix: cchealth"
fi
echo "────────────────────────────────────────────────"
echo ""

exit $((ISSUES > 0 ? 1 : 0))