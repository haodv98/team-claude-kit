#!/usr/bin/env bash
# bootstrap.sh — team-claude-kit setup
#
# Usage:
#   bash bootstrap.sh [options]
#
# Options:
#   --target    <claude|cursor|codex>     Default: claude
#   --languages <ts|typescript|py|...>   Default: typescript
#   --project   <path>                   Cài vào project cụ thể (project scope)
#                                        VD: --project ~/workspace/my-app
#   --yes | -y                           Auto-accept all prompts
#   --dry-run                            Preview only, no changes
#   --rollback                           Rollback lần install trước
#   --help                               Show this help
#
# Examples:
#   bash bootstrap.sh                                        # global only
#   bash bootstrap.sh --project ~/workspace/my-app          # global + project
#   bash bootstrap.sh --project . --target claude --yes     # project = thư mục hiện tại
#   bash bootstrap.sh --target codex --languages "ts py"
#   bash bootstrap.sh --target claude --rollback

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ────────────────────────────────────────────────────
TARGET="claude"
LANGUAGES="typescript"
PROJECT_PATH=""       # empty = global only; set = cài thêm project scope
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
    --yes|-y)    YES=true;     shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --rollback)
      source "$SCRIPT_DIR/lib/common.sh"
      source "$SCRIPT_DIR/lib/backup.sh"
      step_rollback
      exit $?
      ;;
    --help|-h)  show_help ;;
    *)
      echo "Unknown option: $1"
      echo "Run: bash bootstrap.sh --help"
      exit 1 ;;
  esac
done

# Normalize language aliases
normalize_langs() {
  local out=""
  for lang in $1; do
    case "$lang" in
      ts|typescript) out="$out typescript" ;;
      py|python)     out="$out python"     ;;
      go|golang)     out="$out golang"     ;;
      rs|rust)       out="$out rust"       ;;
      php)           out="$out php"        ;;
      web)           out="$out web"        ;;
      swift)         out="$out swift"      ;;
      *)             out="$out $lang"      ;;
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

export DRY_RUN YES TARGET LANGUAGES PROJECT_PATH SCRIPT_DIR ERRORS

# ─── Load modules ────────────────────────────────────────────────
for _lib in common backup ecc mcp gitnexus codex aliases project; do
  _f="$SCRIPT_DIR/lib/${_lib}.sh"
  if [ ! -f "$_f" ]; then
    echo "Missing lib file: $_f"
    exit 1
  fi
  source "$_f"
done
unset _lib _f

# ─── Main ────────────────────────────────────────────────────────
main() {
  header "team-claude-kit setup"
  info "Target   : $TARGET"
  info "Languages: $LANGUAGES"
  [ -n "$PROJECT_PATH" ] && info "Project  : $PROJECT_PATH"
  [ "$DRY_RUN" = true ] && warn "DRY RUN — no changes will be made"
  [ "$YES"     = true ] && info "Auto-yes mode"
  echo ""

  case "$TARGET" in
    claude|cursor)
      run_step "Backup config"      step_backup
      run_step "ECC + ccg-workflow" step_ecc
      run_step "MCP servers"        step_mcp
      run_step "GitNexus"           step_gitnexus
      run_step "Shell aliases"      step_aliases
      ;;
    codex)
      run_step "Backup config"  step_backup
      run_step "Codex CLI"      step_codex
      run_step "GitNexus"       step_gitnexus
      run_step "Shell aliases"  step_aliases
      ;;
  esac

  # Project scope — chạy sau global, override lên trên
  if [ -n "$PROJECT_PATH" ]; then
    run_step "Project scope → $PROJECT_PATH" step_project
  fi

  print_summary
}

main