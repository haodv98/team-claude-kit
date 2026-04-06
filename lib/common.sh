#!/usr/bin/env bash
# lib/common.sh — Logging, helpers, step runner

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()     { echo -e "${GREEN}  ✓${NC} $1"; }
info()   { echo -e "${CYAN}  →${NC} $1"; }
warn()   { echo -e "${YELLOW}  ⚠${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${NC}"; }
step()   { echo -e "\n${BOLD}▶ $1${NC}"; }

# Run a command, or print it in dry-run mode
run() {
  if [ "${DRY_RUN:-false}" = true ]; then
    echo -e "${DIM}  [dry-run] $*${NC}"
    return 0
  fi
  eval "$@"
}

# Prompt — auto-yes in non-interactive or --yes mode
ask() {
  [ "${YES:-false}" = true ] && return 0
  [ ! -t 0 ]                 && return 0
  read -r -p "$(echo -e "  ${YELLOW}?${NC} $1 (y/n) ")" -n 1; echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# Check if command exists
has() { command -v "$1" &>/dev/null; }

# ─── Step runner — bước nào fail thì log + tiếp tục ─────────────
# Usage: run_step "Label" function_name
run_step() {
  local label="$1"
  local fn="$2"
  local start; start=$(date +%s)

  echo ""
  echo -e "${BOLD}┌─ Step: $label ${NC}"

  if "$fn" 2>&1 | sed 's/^/│ /'; then
    local dur=$(( $(date +%s) - start ))
    echo -e "${GREEN}└─ ✓ $label${NC} ${DIM}(${dur}s)${NC}"
  else
    local code=$?
    local msg="$label failed (exit $code)"
    echo -e "${RED}└─ ✗ $msg${NC}"
    ERRORS+=("$msg")
    # Không exit — tiếp tục bước tiếp theo
  fi
}

# ─── Final summary ────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✓ All steps completed successfully!${NC}"
  else
    echo -e "${YELLOW}${BOLD}  ⚠ Completed with ${#ERRORS[@]} error(s):${NC}"
    for e in "${ERRORS[@]}"; do
      echo -e "    ${RED}✗${NC} $e"
    done
    echo ""
    echo -e "  ${DIM}Xem log từng bước ở trên để biết chi tiết.${NC}"
    echo -e "  ${DIM}Chạy lại sau khi fix: bash bootstrap.sh --target ${TARGET} --languages \"${LANGUAGES}\"${NC}"
  fi

  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Next steps:"
  echo "  1. source ~/.zshrc"
  echo "  2. claude login  (nếu chưa)"
  echo "  3. ccstart"
  echo ""
  echo "  Với mỗi project mới:"
  echo "    cd [project] && gitnexus analyze --skills"
  echo ""
  echo -e "  ${YELLOW}Superpowers (trong Claude Code session):${NC}"
  echo "    /plugin marketplace add obra/superpowers-marketplace"
  echo "    /plugin install superpowers@superpowers-marketplace"
  echo ""
}