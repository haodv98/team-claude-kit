#!/usr/bin/env bash
# lib/project.sh — Cài .claude/ scope vào một project cụ thể
#
# Layout sau khi cài:
#   <project>/
#   ├── CLAUDE.md                  ← team context (override global)
#   └── .claude/
#       ├── settings.json          ← project-level settings
#       ├── agents/                ← copy từ ECC + kit
#       ├── skills/                ← copy từ ECC + kit
#       └── commands/              ← copy từ ECC + kit
#
# Global (~/.claude/) vẫn là nền — project chỉ override những gì cần thiết.

ECC_DIR="$HOME/everything-claude-code"

step_project() {
  local proj="${PROJECT_PATH:?PROJECT_PATH is not set}"

  # ── Validate path ─────────────────────────────────────────────
  section "Validate project path"

  if [ ! -d "$proj" ]; then
    if ask "Thư mục '$proj' chưa tồn tại. Tạo mới?"; then
      run "mkdir -p '$proj'"
      ok "Created $proj"
    else
      warn "Bỏ qua project scope — thư mục không tồn tại"
      return 1
    fi
  fi

  # Resolve absolute path
  proj="$(cd "$proj" && pwd)"
  ok "Project path: $proj"

  # ── Backup .claude/ hiện tại của project ──────────────────────
  section "Backup project .claude/"

  local dot_claude="$proj/.claude"
  if [ -d "$dot_claude" ] && [ "$(ls -A "$dot_claude" 2>/dev/null)" ]; then
    local bak="$proj/.claude.bak.$(date +%Y%m%d-%H%M%S)"
    if ask "Backup .claude/ hiện tại của project?"; then
      run "cp -r '$dot_claude' '$bak'"
      ok "Backed up → $bak"
    fi
  fi

  # ── Tạo cấu trúc .claude/ ─────────────────────────────────────
  section "Tạo .claude/ structure"

  run "mkdir -p '$dot_claude'/{agents,skills,commands}"
  ok ".claude/ structure ready"

  # ── agents/ ───────────────────────────────────────────────────
  section "Install agents"
  _install_to_project "$proj" "agents" "*.md"

  # ── skills/ ───────────────────────────────────────────────────
  section "Install skills"
  _install_to_project "$proj" "skills" "*.md"

  # ── commands/ ─────────────────────────────────────────────────
  section "Install commands"
  _install_to_project "$proj" "commands" "*.md"

  # ── settings.json ─────────────────────────────────────────────
  section "Install settings.json"
  _install_settings "$proj"

  # ── CLAUDE.md ─────────────────────────────────────────────────
  section "Install CLAUDE.md"
  _install_claude_md "$proj"

  # ── .gitignore patch ──────────────────────────────────────────
  section "Patch .gitignore"
  _patch_gitignore "$proj"

  # ── GitNexus index ────────────────────────────────────────────
  section "GitNexus index"
  if has gitnexus && ask "Index project này với GitNexus?"; then
    info "Indexing $proj..."
    local tmp; tmp=$(mktemp)
    if (cd "$proj" && gitnexus analyze --skills) > "$tmp" 2>&1; then
      ok "GitNexus index done → $proj/.gitnexus/"
    else
      warn "gitnexus analyze failed:"; sed 's/^/    /' "$tmp"
    fi
    rm -f "$tmp"
  fi

  _tty ""
  ok "Project scope installed → $proj"
  _tty "  ${DIM}Global (~/.claude/) vẫn là nền — project override lên trên${NC}"
}

# ─── Helpers ─────────────────────────────────────────────────────

# Copy files từ kit và ECC vào .claude/<subdir>/ của project
# Thứ tự ưu tiên: ECC → kit (kit cuối cùng = override cao nhất)
_install_to_project() {
  local proj="$1" subdir="$2" pattern="$3"
  local dest="$proj/.claude/$subdir"
  local copied=0

  # 1. Từ ECC
  local ecc_src="$ECC_DIR/$subdir"
  if [ -d "$ecc_src" ]; then
    for f in "$ecc_src"/$pattern; do
      [ -e "$f" ] || continue
      local name; name="$(basename "$f")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy ECC/$subdir/$name → .claude/$subdir/"
      else
        cp "$f" "$dest/$name" 2>/dev/null && ((copied++)) || true
      fi
    done
    # ECC có thể dùng subdirectory cho skills
    for d in "$ecc_src"/*/; do
      [ -d "$d" ] || continue
      local dname; dname="$(basename "$d")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy ECC/$subdir/$dname/ → .claude/$subdir/"
      else
        cp -r "$d" "$dest/$dname" 2>/dev/null && ((copied++)) || true
      fi
    done
  fi

  # 2. Từ kit (override ECC nếu cùng tên)
  local kit_src="$SCRIPT_DIR/claude/$subdir"
  if [ -d "$kit_src" ]; then
    for f in "$kit_src"/$pattern; do
      [ -e "$f" ] || continue
      local name; name="$(basename "$f")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy kit/$subdir/$name → .claude/$subdir/"
      else
        cp "$f" "$dest/$name" 2>/dev/null && ((copied++)) || true
      fi
    done
  fi

  if [ $copied -gt 0 ]; then
    ok "$copied $subdir installed → .claude/$subdir/"
  else
    info "Không có $subdir files — bỏ qua"
  fi
}

# settings.json cho project — nhẹ hơn global, chỉ override cần thiết
_install_settings() {
  local proj="$1"
  local dest="$proj/.claude/settings.json"

  # Nếu đã có, hỏi trước khi ghi đè
  if [ -f "$dest" ]; then
    if ! ask "settings.json đã tồn tại trong project. Ghi đè?"; then
      info "Giữ nguyên settings.json hiện tại"
      return 0
    fi
  fi

  # Dùng settings.json của kit nếu có, không thì tạo minimal
  local kit_settings="$SCRIPT_DIR/claude/settings.json"
  if [ -f "$kit_settings" ]; then
    run "cp '$kit_settings' '$dest'"
    ok "settings.json copied from kit"
  else
    [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $dest"; return 0; }
    cat > "$dest" << 'JSON'
{
  "model": "claude-sonnet-4-6",
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
JSON
    ok "settings.json created (minimal)"
  fi
}

# CLAUDE.md — copy từ kit, thêm project-specific header
_install_claude_md() {
  local proj="$1"
  local dest="$proj/CLAUDE.md"
  local kit_md="$SCRIPT_DIR/claude/CLAUDE.md"

  if [ -f "$dest" ]; then
    if ! ask "CLAUDE.md đã tồn tại. Ghi đè?"; then
      info "Giữ nguyên CLAUDE.md hiện tại"
      return 0
    fi
  fi

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $dest"; return 0; }

  local proj_name; proj_name="$(basename "$proj")"

  # Header project-specific + nội dung từ kit
  {
    cat << MD
# $proj_name — Claude Context

> Project-level override. Global context tại ~/.claude/CLAUDE.md vẫn áp dụng.
> Sửa file này để customize riêng cho project này.

MD
    # Append team CLAUDE.md nếu có
    [ -f "$kit_md" ] && cat "$kit_md"
  } > "$dest"

  ok "CLAUDE.md created → $dest"
}

# Thêm .claude/sessions/ vào .gitignore (sessions không nên commit)
_patch_gitignore() {
  local proj="$1"
  local gi="$proj/.gitignore"

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] patch $gi"; return 0; }

  local entries=(
    ".claude/sessions/"
    ".claude/audit.log"
    ".gitnexus/"
  )

  local added=0
  for entry in "${entries[@]}"; do
    if ! grep -qxF "$entry" "$gi" 2>/dev/null; then
      echo "$entry" >> "$gi"
      ((added++))
    fi
  done

  [ $added -gt 0 ] \
    && ok "Added $added entries to .gitignore" \
    || info ".gitignore đã có các entries cần thiết"
}