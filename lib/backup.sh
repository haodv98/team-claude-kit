#!/usr/bin/env bash
# lib/backup.sh — Backup config hiện tại trước khi install

BACKUP_ROOT="$HOME/.team-kit-backups"

step_backup() {
  section "Backup config hiện tại"

  # Xác định thư mục cần backup theo target
  local dirs=()
  case "$TARGET" in
    claude)
      [ -d "$HOME/.claude" ] && dirs+=("$HOME/.claude")
      ;;
    cursor)
      [ -d "$HOME/.cursor" ]           && dirs+=("$HOME/.cursor")
      [ -d "$HOME/.config/cursor" ]    && dirs+=("$HOME/.config/cursor")
      ;;
    codex)
      [ -d "$HOME/.codex" ] && dirs+=("$HOME/.codex")
      ;;
  esac

  # Không có gì để backup
  if [ ${#dirs[@]} -eq 0 ]; then
    info "Không tìm thấy config hiện tại của $TARGET — bỏ qua backup"
    return 0
  fi

  # Hiển thị những gì sẽ backup
  _tty ""
  _tty "  Sẽ backup:"
  for d in "${dirs[@]}"; do
    local size; size=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "?")
    _tty "    ${DIM}${d}${NC}  ${DIM}(${size})${NC}"
  done

  if ! ask "Backup config $TARGET trước khi cài?"; then
    info "Bỏ qua backup"
    return 0
  fi

  # Tạo backup có timestamp
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  local backup_dir="$BACKUP_ROOT/$TARGET-$ts"

  if [ "${DRY_RUN:-false}" = true ]; then
    info "[dry-run] mkdir -p $backup_dir"
    for d in "${dirs[@]}"; do
      info "[dry-run] cp -r $d → $backup_dir/"
    done
    return 0
  fi

  mkdir -p "$backup_dir"

  local failed=0
  for d in "${dirs[@]}"; do
    local name; name=$(basename "$d")
    if cp -r "$d" "$backup_dir/$name" 2>/dev/null; then
      ok "Backed up: $d → $backup_dir/$name"
    else
      warn "Không thể backup: $d"
      ((failed++)) || true
    fi
  done

  if [ $failed -eq 0 ]; then
    ok "Backup hoàn tất → $backup_dir"
    _cleanup_old_backups
  else
    warn "Backup hoàn tất với $failed lỗi → $backup_dir"
  fi

  # Lưu path để có thể rollback
  echo "$backup_dir" > "$BACKUP_ROOT/.last-$TARGET"
}

# Xóa backup cũ, chỉ giữ 5 bản gần nhất
_cleanup_old_backups() {
  [ ! -d "$BACKUP_ROOT" ] && return 0
  local count
  count=$(ls -d "$BACKUP_ROOT/$TARGET-"* 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 5 ]; then
    ls -dt "$BACKUP_ROOT/$TARGET-"* 2>/dev/null | tail -n +"$((5+1))" | while read -r old; do
      rm -rf "$old"
      info "Đã xóa backup cũ: $old"
    done
  fi
}

# Rollback về backup gần nhất
step_rollback() {
  section "Rollback $TARGET config"

  local last_file="$BACKUP_ROOT/.last-$TARGET"
  if [ ! -f "$last_file" ]; then
    warn "Không tìm thấy backup cho $TARGET"
    info "Backup được lưu tại: $BACKUP_ROOT/"
    return 1
  fi

  local backup_dir; backup_dir=$(cat "$last_file")
  if [ ! -d "$backup_dir" ]; then
    warn "Backup dir không còn tồn tại: $backup_dir"
    return 1
  fi

  _tty ""
  _tty "  Sẽ restore từ: ${CYAN}$backup_dir${NC}"

  if ! ask "Rollback $TARGET về backup này?"; then
    info "Bỏ qua rollback"
    return 0
  fi

  case "$TARGET" in
    claude)
      [ -d "$backup_dir/.claude" ] && cp -r "$backup_dir/.claude" "$HOME/" && ok "Restored ~/.claude" ;;
    cursor)
      [ -d "$backup_dir/.cursor" ]        && cp -r "$backup_dir/.cursor" "$HOME/" && ok "Restored ~/.cursor"
      [ -d "$backup_dir/cursor" ]         && cp -r "$backup_dir/cursor" "$HOME/.config/" && ok "Restored ~/.config/cursor" ;;
    codex)
      [ -d "$backup_dir/.codex" ] && cp -r "$backup_dir/.codex" "$HOME/" && ok "Restored ~/.codex" ;;
  esac

  ok "Rollback hoàn tất"
}