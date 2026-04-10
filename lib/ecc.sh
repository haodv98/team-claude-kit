#!/usr/bin/env bash

# lib/ecc.sh — Everything Claude Code + ccg-workflow
# Phần bổ sung: version pinning và changelog check

ECC_DIR="$HOME/everything-claude-code"

# ─── [MỚI] File lưu version đang dùng ───────────────────────────
ECC_VERSION_FILE="$SCRIPT_DIR/.ecc-version"

# Đọc pinned commit từ file (nếu có)
get_pinned_version() {
  [[ -f "$ECC_VERSION_FILE" ]] && cat "$ECC_VERSION_FILE" || echo ""
}

# Lưu commit hiện tại làm pinned version
save_pinned_version() {
  local commit
  commit="$(git -C "$ECC_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
  echo "$commit" > "$ECC_VERSION_FILE"
  info "Pinned ECC version: ${commit:0:8}"
}

# ─── Install ECC (lần đầu) ───────────────────────────────────────
step_ecc() {
  if [[ ! -d "$ECC_DIR" ]]; then
    info "Cloning Everything Claude Code..."
    run git clone https://github.com/affaan-m/everything-claude-code.git "$ECC_DIR"
    save_pinned_version
  else
    info "ECC đã tồn tại tại $ECC_DIR — skip clone"
    # Nếu chưa có pinned version thì lưu commit hiện tại
    [[ -z "$(get_pinned_version)" ]] && save_pinned_version
  fi

  # Chạy ECC install.sh
  local install_sh="$ECC_DIR/install.sh"
  if [[ ! -f "$install_sh" ]]; then
    err_log "Không tìm thấy $install_sh — hãy chạy lại sau khi git pull"
    return 1
  fi

  run bash "$install_sh" --target "$TARGET" "$LANGUAGES"
 
  # ccg-workflow runtime
  _install_ccg_workflow
}

_install_ccg_workflow() {
  info "Cài ccg-workflow runtime..."
  if [[ "${DRY_RUN:-false}" == true ]]; then
    info "[dry-run] npm install -g ccg-workflow"
    return 0
  fi
  npm install -g ccg-workflow 2>/dev/null || \
    warn "ccg-workflow install thất bại — /multi-* commands sẽ không hoạt động"
}

# ─── ccupdate — script độc lập, không phụ thuộc common.sh ────────
# (subshell mới, không có context của bootstrap)
ecc_update() {
  # Inline helpers — không phụ thuộc common.sh
  local _info='\033[0;34m[info]\033[0m'
  local _warn='\033[1;33m[warn]\033[0m'
  local _err='\033[0;31m[error]\033[0m'

  local ecc_dir="$HOME/everything-claude-code"
  local version_file
  # Tìm SCRIPT_DIR từ symlink của ccupdate alias
  version_file="$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")")/.ecc-version"

  if [[ ! -d "$ecc_dir" ]]; then
    echo -e "$_err ECC chưa được cài tại $ecc_dir. Chạy bootstrap trước."
    return 1
  fi

  git -C "$ecc_dir" fetch origin --quiet

  local remote_commit local_commit
  remote_commit="$(git -C "$ecc_dir" rev-parse origin/main)"
  local_commit="$(git -C "$ecc_dir" rev-parse HEAD)"

  if [[ "$remote_commit" == "$local_commit" ]]; then
    echo -e "$_info ECC đã ở phiên bản mới nhất (${local_commit:0:8})"
    return 0
  fi

  echo ""
  echo "📦 ECC update có sẵn:"
  echo "   Current : ${local_commit:0:8}"
  echo "   Latest  : ${remote_commit:0:8}"
  echo ""
  echo "── Thay đổi ────────────────────────────────────────────"
  git -C "$ecc_dir" log --oneline "${local_commit}..${remote_commit}" | head -20
  echo "────────────────────────────────────────────────────────"
  echo ""

  local breaking
  breaking="$(git -C "$ecc_dir" log --oneline "${local_commit}..${remote_commit}" \
    | grep -iE "breaking|BREAKING|major" || true)"
  if [[ -n "$breaking" ]]; then
    echo -e "$_warn ⚠️  Có thể có BREAKING CHANGES:"
    echo "$breaking"
    echo ""
  fi

  echo -n "Tiến hành update? [y/N] "
  read -r answer
  [[ "$answer" != [yY] ]] && { echo -e "$_info Đã hủy."; return 0; }

  git -C "$ecc_dir" pull origin main
  echo "${remote_commit}" > "$version_file" 2>/dev/null || true

  local target="${TARGET:-claude}"
  local langs="${LANGUAGES:-typescript}"
  bash "$ecc_dir/install.sh" --target "$target" --languages "$langs"

  echo -e "$_info ✅ ECC đã được update lên ${remote_commit:0:8}"
}

# Export để alias ccupdate có thể gọi trực tiếp
export -f ecc_update 2>/dev/null || true