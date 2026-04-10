#!/usr/bin/env bash

# lib/graphify.sh — Graphify knowledge graph cho codebase
# Thay thế: lib/gitnexus.sh
# Source: https://github.com/safishamsi/graphify (branch v1)

GRAPHIFY_SKILL_URL="https://raw.githubusercontent.com/safishamsi/graphify/v1/skills/graphify/skill.md"
GRAPHIFY_SKILL_DIR="$HOME/.claude/skills/graphify"
GRAPHIFY_CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# ─── Check Python 3.10+ ──────────────────────────────────────────
_check_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    err_log "python3 không tìm thấy — Graphify yêu cầu Python 3.10+"
    return 1
  fi

  local py_ver
  py_ver="$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null)"
  local py_major
  py_major="$(python3 -c 'import sys; print(sys.version_info.major)' 2>/dev/null)"

  if [[ "$py_major" -lt 3 || ( "$py_major" -eq 3 && "$py_ver" -lt 10 ) ]]; then
    err_log "Python $(python3 --version) — Graphify yêu cầu Python 3.10+"
    return 1
  fi

  info "Python $(python3 --version) — OK"
  return 0
}

# ─── Install Graphify CLI ─────────────────────────────────────────
_install_graphify_cli() {
  if command -v graphify >/dev/null 2>&1; then
    info "graphify CLI đã có — $(graphify --version 2>/dev/null || echo 'installed')"
    return 0
  fi

  info "Cài graphify CLI (pip install graphifyy)..."
  # Package PyPI tạm thời là 'graphifyy' (2 chữ y) trong khi tên 'graphify' đang được reclaim
  run pip install graphifyy

  # Verify sau khi cài
  if ! command -v graphify >/dev/null 2>&1; then
    warn "graphify CLI chưa thấy trong PATH sau khi cài."
    warn "Thử: pip install --user graphifyy && export PATH=\$PATH:\$HOME/.local/bin"
    return 1
  fi

  info "graphify CLI đã cài thành công"
}

# ─── Cài Skill file cho Claude Code ──────────────────────────────
_install_graphify_skill() {
  info "Cài Graphify skill cho Claude Code..."

  run mkdir -p "$GRAPHIFY_SKILL_DIR"
  run curl -fsSL "$GRAPHIFY_SKILL_URL" -o "$GRAPHIFY_SKILL_DIR/SKILL.md"

  if [[ ! -f "$GRAPHIFY_SKILL_DIR/SKILL.md" && "$DRY_RUN" != true ]]; then
    err_log "Không tải được skill.md từ GitHub"
    return 1
  fi

  info "Skill file: $GRAPHIFY_SKILL_DIR/SKILL.md"
}

# ─── Thêm entry vào ~/.claude/CLAUDE.md ──────────────────────────
_configure_claude_md() {
  local entry
  entry='- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.'

  # Đảm bảo thư mục và file tồn tại
  run mkdir -p "$(dirname "$GRAPHIFY_CLAUDE_MD")"
  [[ ! -f "$GRAPHIFY_CLAUDE_MD" ]] && run touch "$GRAPHIFY_CLAUDE_MD"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Sẽ thêm graphify entry vào $GRAPHIFY_CLAUDE_MD"
    return 0
  fi

  if grep -q "graphify" "$GRAPHIFY_CLAUDE_MD" 2>/dev/null; then
    info "graphify entry đã có trong CLAUDE.md — skip"
    return 0
  fi

  # Thêm vào cuối file, với blank line ngăn cách
  echo "" >> "$GRAPHIFY_CLAUDE_MD"
  echo "$entry" >> "$GRAPHIFY_CLAUDE_MD"
  info "Đã thêm graphify vào $GRAPHIFY_CLAUDE_MD"
}

# ─── Entry point — gọi từ bootstrap.sh ──────────────────────────
step_graphify() {
  _check_python || return 1
  _install_graphify_cli
  _install_graphify_skill
  _configure_claude_md
  info "✅ Graphify setup hoàn tất"
  info "   Dùng trong Claude Code: /graphify ."
}