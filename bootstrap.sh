#!/usr/bin/env bash
# bootstrap.sh — team-claude-kit setup
#
# Usage:
#   bash bootstrap.sh [options]
#
# Options:
#   --target   <claude|cursor>         Default: claude
#   --languages <ts|typescript|py|...> Default: typescript
#                                      Nhiều ngôn ngữ: --languages "typescript python"
#   --yes | -y                         Auto-accept all prompts
#   --dry-run                          Preview only, no changes
#   --help                             Show this help
#
# Examples:
#   bash bootstrap.sh
#   bash bootstrap.sh --target claude --languages typescript
#   bash bootstrap.sh --target cursor --languages "typescript python"
#   bash bootstrap.sh --yes --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ────────────────────────────────────────────────────
TARGET="claude"
LANGUAGES="typescript"
DRY_RUN=false
YES=false
ERRORS=()   # collect non-fatal errors

# Auto-yes in piped/non-interactive mode
[ ! -t 0 ] && YES=true

# ─── Parse args ──────────────────────────────────────────────────
show_help() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ -z "${2:-}" ]] && { echo "--target requires a value (claude|cursor)"; exit 1; }
      TARGET="$2"; shift 2 ;;
    --languages)
      [[ -z "${2:-}" ]] && { echo "--languages requires a value"; exit 1; }
      LANGUAGES="$2"; shift 2 ;;
    --yes|-y)   YES=true;     shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)  show_help ;;
    *)
      echo "Unknown option: $1"
      echo "Run: bash bootstrap.sh --help"
      exit 1 ;;
  esac
done

# Normalize language aliases
normalize_langs() {
  local raw="$1" out=""
  for lang in $raw; do
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
  claude|cursor) ;;
  *) echo "Invalid --target '$TARGET'. Must be: claude | cursor"; exit 1 ;;
esac

export DRY_RUN YES TARGET LANGUAGES SCRIPT_DIR ERRORS

# ─── Load modules ────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/ecc.sh"
source "$SCRIPT_DIR/lib/mcp.sh"
source "$SCRIPT_DIR/lib/gitnexus.sh"

# ─── Main ────────────────────────────────────────────────────────
main() {
  header "team-claude-kit setup"

  info "Target   : $TARGET"
  info "Languages: $LANGUAGES"
  [ "$DRY_RUN" = true ] && warn "DRY RUN — no changes will be made"
  [ "$YES"     = true ] && info "Auto-yes mode"
  echo ""

  run_step "ECC + ccg-workflow" step_ecc
  run_step "MCP servers"        step_mcp
  run_step "GitNexus"           step_gitnexus
  run_step "Shell aliases"      step_aliases

  print_summary
}

main