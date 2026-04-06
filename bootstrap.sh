#!/usr/bin/env bash
# bootstrap.sh — team-claude-kit setup
#
# Usage:
#   bash bootstrap.sh [options]
#
# Options:
#   --target   <claude|cursor|codex>   Default: claude
#   --languages <ts|typescript|py|...> Default: typescript
#                                      Nhiều ngôn ngữ: --languages "typescript python"
#   --yes | -y                         Auto-accept all prompts
#   --dry-run                          Preview only, no changes
#   --help                             Show this help
#
# Examples:
#   bash bootstrap.sh
#   bash bootstrap.sh --target claude --languages typescript
#   bash bootstrap.sh --target codex --languages "typescript python"
#   bash bootstrap.sh --target cursor --languages typescript
#   bash bootstrap.sh --yes --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ────────────────────────────────────────────────────
TARGET="claude"
LANGUAGES="typescript"
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
    --yes|-y)    YES=true;     shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --rollback)
      # Rollback sau khi load modules
      source "$SCRIPT_DIR/lib/common.sh"
      source "$SCRIPT_DIR/lib/backup.sh"
      # TARGET cần được parse trước --rollback, ví dụ:
      # bash bootstrap.sh --target codex --rollback
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

export DRY_RUN YES TARGET LANGUAGES SCRIPT_DIR ERRORS

# ─── Load modules ────────────────────────────────────────────────
for _lib in common backup ecc mcp gitnexus codex aliases; do
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

  print_summary
}

main