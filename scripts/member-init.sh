#!/usr/bin/env bash
# scripts/member-init.sh — Per-member local profile for a project
#
# Creates .claude/member.local.json (gitignored, per-machine, per-project).
# Called automatically by ccclaim/ccunclaim to track active task.
#
# Usage:
#   ccme               # show current member status
#   ccme init          # set up or update member profile
#   ccme phase <N>     # change current phase
#   ccme sprint <N>    # change current sprint
#   ccme task <ID>     # manually set active task

set -eo pipefail

MEMBER_FILE="$(pwd)/.claude/member.local.json"

# ── JSON helpers (python3 guaranteed by bootstrap) ────────────
_read() {
  python3 -c "
import json, sys
try:
    d = json.load(open('$MEMBER_FILE'))
    v = d.get('$1', '')
    print(v if v is not None else '')
except:
    print('')
" 2>/dev/null
}

_write() {
  # Usage: _write key value
  local key="$1" val="$2"
  mkdir -p "$(dirname "$MEMBER_FILE")"
  python3 -c "
import json, os, datetime
path = '$MEMBER_FILE'
d = {}
if os.path.exists(path):
    try: d = json.load(open(path))
    except: pass
d['$key'] = '$val'
d['updatedAt'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open(path, 'w'), indent=2)
" 2>/dev/null
}

_write_all() {
  # Usage: _write_all name email phase sprint
  local name="$1" email="$2" phase="$3" sprint="$4"
  mkdir -p "$(dirname "$MEMBER_FILE")"
  python3 -c "
import json, os, datetime
path = '$MEMBER_FILE'
d = {}
if os.path.exists(path):
    try: d = json.load(open(path))
    except: pass
d.update({'name': '''$name''', 'email': '''$email''', 'phase': int('$phase') if '$phase'.isdigit() else 1, 'sprint': int('$sprint') if '$sprint'.isdigit() else 1})
d['updatedAt'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open(path, 'w'), indent=2)
" 2>/dev/null
}

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Show status ────────────────────────────────────────────────
_show() {
  if [ ! -f "$MEMBER_FILE" ]; then
    printf "\n  ${YELLOW}⚠  No member profile. Run: ccme init${NC}\n\n"
    return 1
  fi

  local name email phase sprint active_task
  name="$(_read name)"
  email="$(_read email)"
  phase="$(_read phase)"
  sprint="$(_read sprint)"
  active_task="$(_read activeTask)"
  proj="$(basename "$(pwd)")"

  printf "\n"
  printf "  ${BOLD}%-12s${NC} %s\n" "Member:" "${name:-unknown}"
  [ -n "$email" ] && printf "  ${BOLD}%-12s${NC} %s\n" "Email:" "$email"
  printf "  ${BOLD}%-12s${NC} Phase %s  Sprint %s\n" "Phase:" "${phase:-1}" "${sprint:-1}"
  printf "  ${BOLD}%-12s${NC} %s\n" "Project:" "$proj"
  printf "  ${BOLD}%-12s${NC} %s\n" "Active task:" "${active_task:-none}"

  # Show claimed tasks for this member
  local claimed_file="$(pwd)/todos/claimed.md"
  if [ -f "$claimed_file" ] && grep -q "$name" "$claimed_file" 2>/dev/null; then
    printf "\n  ${BOLD}Claimed:${NC}\n"
    grep "$name" "$claimed_file" | grep -v "^#" | grep -v "^|.*Member" | while IFS='|' read -r _ _ task files ts _; do
      task="${task// /}"; files="${files// /}"
      [ -n "$task" ] && printf "    → ${CYAN}%s${NC}  ${DIM}%s${NC}\n" "$task" "$files"
    done
  fi
  printf "\n"
}

# ── Init wizard ────────────────────────────────────────────────
_init() {
  local name email phase sprint

  # Defaults from git config + existing profile
  name="$(_read name)"; [ -z "$name" ] && name="$(git config user.name 2>/dev/null || echo "")"
  email="$(_read email)"; [ -z "$email" ] && email="$(git config user.email 2>/dev/null || echo "")"
  phase="$(_read phase)"; [ -z "$phase" ] && phase="1"
  sprint="$(_read sprint)"; [ -z "$sprint" ] && sprint="1"

  printf "\n  ${BOLD}Member setup for: %s${NC}\n\n" "$(basename "$(pwd)")"

  if [ -t 0 ]; then
    printf "  Name   [%s]: " "$name"; read -r inp < /dev/tty; [ -n "$inp" ] && name="$inp"
    printf "  Email  [%s]: " "$email"; read -r inp < /dev/tty; [ -n "$inp" ] && email="$inp"
    printf "  Phase  [%s]: " "$phase"; read -r inp < /dev/tty; [ -n "$inp" ] && phase="$inp"
    printf "  Sprint [%s]: " "$sprint"; read -r inp < /dev/tty; [ -n "$inp" ] && sprint="$inp"
  else
    # Non-interactive: use defaults
    [ -z "$name" ] && name="${USER:-unknown}"
  fi

  _write_all "$name" "$email" "$phase" "$sprint"
  printf "\n  ${GREEN}✅ Profile saved → .claude/member.local.json${NC}\n"
  _show
}

# ── Main ──────────────────────────────────────────────────────
case "${1:-show}" in
  init)   _init ;;
  phase)
    [ -z "${2:-}" ] && { printf "Usage: ccme phase <N>\n"; exit 1; }
    _write "phase" "$2" && printf "  Phase → %s\n" "$2" ;;
  sprint)
    [ -z "${2:-}" ] && { printf "Usage: ccme sprint <N>\n"; exit 1; }
    _write "sprint" "$2" && printf "  Sprint → %s\n" "$2" ;;
  task)
    [ -z "${2:-}" ] && { printf "Usage: ccme task <TASK-ID>\n"; exit 1; }
    _write "activeTask" "$2" && printf "  Active task → %s\n" "$2" ;;
  show|*) _show ;;
esac
