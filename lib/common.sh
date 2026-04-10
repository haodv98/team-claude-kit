#!/usr/bin/env bash
# lib/common.sh — Logging, helpers, step runner

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'

# ─── Logging ─────────────────────────────────────────────────────
# Ghi ra /dev/tty nếu có (interactive), fallback ra stderr (CI/pipe)

_tty() {
  printf "%b\n" "$*" > /dev/tty 2>/dev/null || printf "%b\n" "$*" >&2
}

ok()     { _tty "  ${GREEN}✓${NC}  $1"; }
info()   { _tty "  ${CYAN}→${NC}  $1"; }
warn()   { _tty "  ${YELLOW}⚠${NC}  $1"; }
err_log(){ _tty "  ${RED}✗${NC}  $1"; }

out()    { echo "    $1"; }

header() {
  _tty ""
  _tty "${BOLD}${CYAN}══════════════════════════════════════${NC}"
  _tty "${BOLD}${CYAN}  $1${NC}"
  _tty "${BOLD}${CYAN}══════════════════════════════════════${NC}"
}

section() {
  _tty ""
  _tty "  ${BOLD}${BLUE}▸ $1${NC}"
}

step() { section "$@"; }

# ─── ask() ───────────────────────────────────────────────────────
# CI/pipe: luôn return 0 (auto-yes) vì không có terminal
ask() {
  [ "${YES:-false}" = true ] && return 0

  printf "  ${YELLOW}?${NC}  %s ${DIM}(y/n)${NC} " "$1" > /dev/tty 2>/dev/null || return 0

  local REPLY
  IFS= read -r -n 1 REPLY < /dev/tty 2>/dev/null || return 0
  printf "\n" > /dev/tty 2>/dev/null || true
  [[ "${REPLY:-n}" =~ ^[Yy]$ ]]
}

# ─── run() ───────────────────────────────────────────────────────
run() {
  if [ "${DRY_RUN:-false}" = true ]; then
    _tty "  ${DIM}[dry-run] $*${NC}"
    return 0
  fi
  eval "$@"
}

# ─── has() / need() ──────────────────────────────────────────────
has()  { command -v "$1" &>/dev/null; }
need() { has "$1" || { err_log "$1 required. $2"; exit 1; }; }

# ─── run_step() ──────────────────────────────────────────────────
run_step() {
  local label="$1"
  local fn="$2"
  local start; start=$(date +%s)
  local exit_file; exit_file=$(mktemp)

  _tty ""
  _tty "${BOLD}╔═ Step: ${label}${NC}"
  _tty "║"

  (
    "$fn" 2>&1
    echo $? > "$exit_file"
  ) | while IFS= read -r line; do
    printf "    %s\n" "$line" > /dev/tty 2>/dev/null || printf "    %s\n" "$line" >&2
  done

  local fn_exit=0
  [ -s "$exit_file" ] && fn_exit=$(cat "$exit_file")
  rm -f "$exit_file"

  local dur=$(( $(date +%s) - start ))

  _tty "║"
  if [ "$fn_exit" -eq 0 ]; then
    _tty "${GREEN}╚═ ✓ ${label}${NC} ${DIM}(${dur}s)${NC}"
  else
    _tty "${RED}╚═ ✗ ${label} failed (exit ${fn_exit})${NC}"
    ERRORS+=("${label} (exit ${fn_exit})")
  fi
}

# ─── print_summary() ─────────────────────────────────────────────
print_summary() {
  _tty ""
  _tty "${BOLD}══════════════════════════════════════${NC}"

  if [ ${#ERRORS[@]} -eq 0 ]; then
    _tty "${GREEN}${BOLD}  ✓  All steps completed!${NC}"
  else
    _tty "${YELLOW}${BOLD}  ⚠  Completed with ${#ERRORS[@]} error(s):${NC}"
    for e in "${ERRORS[@]}"; do
      _tty "     ${RED}✗${NC} ${e}"
    done
    _tty ""
    _tty "  ${DIM}Xem log từng bước ở trên để biết chi tiết.${NC}"
    _tty "  ${DIM}Chạy lại sau khi fix:${NC}"
    _tty "  ${DIM}  bash bootstrap.sh --target ${TARGET} --languages \"${LANGUAGES}\"${NC}"
  fi

  _tty "${BOLD}══════════════════════════════════════${NC}"
  _tty ""
  _tty "  Next steps:"
  _tty "  1. source ~/.zshrc"
  _tty "  2. claude login   ${DIM}(nếu chưa)${NC}"
  _tty "  3. ccstart"
  _tty ""
  _tty "  Với mỗi project mới:"
  _tty "    cd [project] && graphify ."
  _tty ""
  _tty "  ${YELLOW}Superpowers (trong Claude Code session):${NC}"
  _tty "    /plugin marketplace add obra/superpowers-marketplace"
  _tty "    /plugin install superpowers@superpowers-marketplace"
  _tty ""
}