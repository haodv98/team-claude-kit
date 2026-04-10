#!/usr/bin/env bash

# bootstrap.sh — team-claude-kit setup
#
# Usage:
#   bash bootstrap.sh [options]
#
# Options:
#   --target <claude|cursor|codex>   Default: claude
#   --languages <ts|py|go|...>       Default: typescript
#   --project <path>                 Cài vào project cụ thể
#   --yes | -y                       Auto-accept all prompts
#   --dry-run                        Preview only, no changes
#   --rollback                       Rollback lần install trước
#   --help                           Show this help

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ────────────────────────────────────────────────────
TARGET="claude"
LANGUAGES="typescript"
PROJECT_PATH=""
DRY_RUN=false
YES=false
ERRORS=()

[ ! -t 0 ] && YES=true

# ─── Parse args ──────────────────────────────────────────────────
show_help() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ -z "${2:-}" ]] && { echo "--target requires a value (claude|cursor|codex)"; exit 1; }
      TARGET="$2"; shift 2 ;;
    --languages)
      [[ -z "${2:-}" ]] && { echo "--languages requires a value"; exit 1; }
      LANGUAGES="$2"; shift 2 ;;
    --project)
      [[ -z "${2:-}" ]] && { echo "--project requires a path"; exit 1; }
      PROJECT_PATH="$2"; shift 2 ;;
    --yes|-y) YES=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --rollback)
      # shellcheck disable=SC1091
      source "$SCRIPT_DIR/lib/common.sh"
      # shellcheck disable=SC1091
      source "$SCRIPT_DIR/lib/backup.sh"
      step_rollback
      exit $?
      ;;
    --help|-h) show_help ;;
    *)
      echo "Unknown option: $1"
      echo "Run: bash bootstrap.sh --help"
      exit 1 ;;
  esac
done

# ─── [MỚI] Dependency check — fail sớm với message rõ ràng ──────
check_dependencies() {
  local missing=()

  # Bắt buộc
  command -v git  >/dev/null 2>&1 || missing+=("git")
  command -v node >/dev/null 2>&1 || missing+=("node (v18+)")
  command -v npm  >/dev/null 2>&1 || missing+=("npm")

  # Node version check
  if command -v node >/dev/null 2>&1; then
    local node_ver
    node_ver=$(node -e "process.exit(parseInt(process.versions.node) < 18 ? 1 : 0)" 2>/dev/null; echo $?)
    [[ "$node_ver" -ne 0 ]] && missing+=("node v18+ (hiện tại: $(node --version))")
  fi

  # Python 3.10+ — cần cho Graphify
  if ! command -v python3 >/dev/null 2>&1; then
    missing+=("python3 (v3.10+) — cần cho Graphify")
  else
    local py_ok
    py_ok="$(python3 -c 'import sys; print(1 if sys.version_info >= (3,10) else 0)' 2>/dev/null)"
    [[ "$py_ok" != "1" ]] && missing+=("python3 v3.10+ (hiện tại: $(python3 --version))")
  fi

  # pip — cần để cài graphifyy
  command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1 || \
    missing+=("pip / pip3 — cần để cài Graphify")

  # Docker — chỉ cần nếu dùng GitHub MCP
  if [[ "$TARGET" == "claude" || "$TARGET" == "cursor" ]]; then
    command -v docker >/dev/null 2>&1 || {
      echo "⚠️  docker không tìm thấy — GitHub MCP sẽ không hoạt động."
      echo "   Bỏ qua nếu bạn không dùng GitHub MCP."
    }
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Thiếu dependencies bắt buộc:"
    for dep in "${missing[@]}"; do
      echo "   • $dep"
    done
    echo ""
    echo "Cài xong rồi chạy lại bootstrap."
    exit 1
  fi
}

# ─── [MỚI] Detect shell + ghi alias đúng file ───────────────────
detect_shell_rc() {
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"

  case "$shell_name" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash)
      # macOS dùng .bash_profile, Linux dùng .bashrc
      if [[ "$(uname)" == "Darwin" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *)    echo "$HOME/.profile" ;;  # fallback an toàn
  esac
}

export SHELL_RC
SHELL_RC="$(detect_shell_rc)"

# ─── Normalize language aliases ──────────────────────────────────
normalize_langs() {
  local out=""
  for lang in $1; do
    case "$lang" in
      ts|typescript) out="$out typescript" ;;
      py|python)     out="$out python" ;;
      go|golang)     out="$out golang" ;;
      rs|rust)       out="$out rust" ;;
      php)           out="$out php" ;;
      web)           out="$out web" ;;
      swift)         out="$out swift" ;;
      *)             out="$out $lang" ;;
    esac
  done
  echo "${out# }"
}

LANGUAGES="$(normalize_langs "$LANGUAGES")"

# Validate target
case "$TARGET" in
  claude|cursor|codex) ;;
  *) echo "Invalid --target '$TARGET'. Must be: claude | cursor | codex"; exit 1 ;;
esac

export DRY_RUN YES TARGET LANGUAGES PROJECT_PATH SCRIPT_DIR SHELL_RC ERRORS

# ─── Load modules ────────────────────────────────────────────────
for _lib in common backup ecc mcp graphify codex aliases project; do
  _f="$SCRIPT_DIR/lib/${_lib}.sh"
  if [ ! -f "$_f" ]; then
    echo "Missing lib file: $_f"
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$_f"
done
unset _lib _f

# ─── Main ────────────────────────────────────────────────────────
main() {
  header "team-claude-kit setup"
  info "Target   : $TARGET"
  info "Languages: $LANGUAGES"
  info "Shell RC : $SHELL_RC"   # [MỚI] hiển thị file alias sẽ được ghi
  [ -n "$PROJECT_PATH" ] && info "Project  : $PROJECT_PATH"
  [ "$DRY_RUN" = true ] && warn "DRY RUN — no changes will be made"
  [ "$YES" = true ]     && info "Auto-yes mode"
  echo ""

  # [MỚI] Chạy dependency check TRƯỚC mọi thứ
  run_step "Kiểm tra dependencies" check_dependencies

  case "$TARGET" in
    claude|cursor)
      run_step "Backup config"      step_backup
      run_step "ECC + ccg-workflow" step_ecc
      run_step "MCP servers"        step_mcp
      run_step "Graphify"           step_graphify
      run_step "Shell aliases"      step_aliases
      ;;
    codex)
      run_step "Backup config" step_backup
      run_step "Codex CLI"     step_codex
      run_step "Graphify"      step_graphify
      run_step "Shell aliases" step_aliases
      ;;
  esac

  if [ -n "$PROJECT_PATH" ]; then
    run_step "Project scope → $PROJECT_PATH" step_project
  fi

  print_summary
}

main