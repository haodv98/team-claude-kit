#!/usr/bin/env bash
# scripts/task-status.sh — Task overview for current phase + conflict detection
#
# Usage:
#   cctasks                   # tasks for current phase (from member.local.json)
#   cctasks --phase 2         # specific phase
#   cctasks --all             # all phases
#   cctasks --conflicts       # show file ownership conflicts
#   cctasks --backlog         # + live Backlog MCP status

set -eo pipefail

MEMBER_FILE="$(pwd)/.claude/member.local.json"
CLAIMED_FILE="$(pwd)/todos/claimed.md"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Read member profile ─────────────────────────────────────────
_member() {
  python3 -c "
import json
try:
    d = json.load(open('$MEMBER_FILE'))
    print(d.get('$1', ''))
except:
    print('')
" 2>/dev/null
}

MY_NAME="$(_member name)"
MY_PHASE="$(_member phase)"; MY_PHASE="${MY_PHASE:-1}"
MY_SPRINT="$(_member sprint)"; MY_SPRINT="${MY_SPRINT:-1}"

# ── Parse task file fields ──────────────────────────────────────
_field() {
  # Usage: _field "**Status:**" file
  grep -m1 "$1" "$2" 2>/dev/null \
    | sed "s/.*$1 *//" \
    | sed 's/ |.*//' \
    | tr -d '\n\r' \
    || echo ""
}

_task_title() {
  grep -m1 "^# " "$1" 2>/dev/null | sed 's/^# //' | sed 's/TASK-[0-9]*: //' || echo "$(basename "$1" .md)"
}

# ── Get claimant from claimed.md ────────────────────────────────
_claimant() {
  local task_id="$1"
  [ ! -f "$CLAIMED_FILE" ] && echo "" && return
  grep "$task_id" "$CLAIMED_FILE" 2>/dev/null | grep -v "^#" | grep -v "Member" \
    | awk -F'|' '{print $2}' | tr -d ' ' | head -1
}

_claimed_files() {
  local task_id="$1"
  [ ! -f "$CLAIMED_FILE" ] && echo "" && return
  grep "$task_id" "$CLAIMED_FILE" 2>/dev/null | grep -v "^#" \
    | awk -F'|' '{print $3}' | tr -d ' ' | head -1
}

# ── Status formatting ───────────────────────────────────────────
_status_fmt() {
  local status="$1"
  case "${status,,}" in
    done)         printf "${GREEN}✓ Done     ${NC}" ;;
    "in progress") printf "${CYAN}● Working  ${NC}" ;;
    review)       printf "${YELLOW}◎ Review   ${NC}" ;;
    blocked)      printf "${RED}✗ Blocked  ${NC}" ;;
    *)            printf "${DIM}○ Backlog  ${NC}" ;;
  esac
}

_priority_fmt() {
  case "${1,,}" in
    critical) printf "${RED}[!]${NC}" ;;
    high)     printf "${YELLOW}[H]${NC}" ;;
    medium)   printf "${DIM}[M]${NC}" ;;
    *)        printf "${DIM}   ${NC}" ;;
  esac
}

# ── Show tasks for one phase ────────────────────────────────────
_show_phase() {
  local phase="$1"
  local task_dir="$(pwd)/tasks/phase-${phase}"

  if [ ! -d "$task_dir" ]; then
    printf "  ${DIM}(no tasks/phase-%s/ directory)${NC}\n" "$phase"
    return
  fi

  local done=0 wip=0 backlog=0 blocked=0

  for f in "$task_dir"/TASK-*.md; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == "TASK-000"* ]] && continue  # skip template

    local fname; fname="$(basename "$f" .md)"
    local title; title="$(_task_title "$f")"
    local status; status="$(_field '\*\*Status:\*\*' "$f")"
    local priority; priority="$(_field '\*\*Priority:\*\*' "$f")"
    local effort; effort="$(_field '\*\*Effort:\*\*' "$f")"
    local claimant; claimant="$(_claimant "$fname")"
    local claimed_files; claimed_files="$(_claimed_files "$fname")"

    # Count by status
    case "${status,,}" in
      done|review) ((done++)) ;;
      "in progress") ((wip++)) ;;
      blocked) ((blocked++)) ;;
      *) ((backlog++)) ;;
    esac

    # Claimant display
    local owner_str=""
    if [ -n "$claimant" ] && [ "$claimant" != "@TBD" ]; then
      if [[ "$claimant" == *"$MY_NAME"* ]]; then
        owner_str="${CYAN}@${claimant}${NC} ${BOLD}← You${NC}"
      else
        owner_str="${BLUE}@${claimant}${NC}"
      fi
    elif [ "${status,,}" = "backlog" ]; then
      owner_str="${YELLOW}(unclaimed)${NC}"
    fi

    # Effort badge
    local eff_str=""
    [ -n "$effort" ] && [ "$effort" != "XS" ] && eff_str=" ${DIM}[$effort]${NC}"

    printf "  %s %s ${DIM}%-14s${NC} %-38s %s%b\n" \
      "$(_status_fmt "$status")" \
      "$(_priority_fmt "$priority")" \
      "$fname" \
      "${title:0:37}" \
      "$owner_str" \
      "$eff_str"
  done

  printf "\n  ${DIM}Phase %s — %s done | %s in progress | %s backlog | %s blocked${NC}\n" \
    "$phase" "$done" "$wip" "$backlog" "$blocked"
}

# ── Show claimed overview ───────────────────────────────────────
_show_claims() {
  printf "\n  ${BOLD}── Active Claims (todos/claimed.md) ──────────────────────${NC}\n"

  if [ ! -f "$CLAIMED_FILE" ]; then
    printf "  ${DIM}(no claimed.md — run ccclaim to start)${NC}\n"
    return
  fi

  local count=0
  while IFS='|' read -r _ member task files ts _; do
    [[ "$task" == *"Branch"* ]] || [[ "$task" == *"---"* ]] && continue
    member="${member// /}"; task="${task// /}"; files="${files// /}"; ts="${ts// /}"
    [ -z "$member" ] || [ -z "$task" ] && continue

    local age=""
    if [ -n "$ts" ]; then
      local ts_s; ts_s=$(date -j -f "%Y-%m-%d %H:%M" "$ts" +%s 2>/dev/null \
                         || date -d "$ts" +%s 2>/dev/null || echo 0)
      local h=$(( ($(date +%s) - ts_s) / 3600 ))
      [ $h -gt 0 ] && age="${DIM}${h}h ago${NC}"
      [ $h -gt 8 ] && age="${YELLOW}${h}h ago ⚠${NC}"  # stale warning
    fi

    local member_color="${BLUE}"
    [[ "$member" == *"$MY_NAME"* ]] && member_color="${CYAN}"

    printf "  ${member_color}@%-18s${NC} ${CYAN}%-14s${NC} ${DIM}%-25s${NC} %b\n" \
      "$member" "$task" "${files:0:24}" "$age"
    ((count++))
  done < "$CLAIMED_FILE"

  [ $count -eq 0 ] && printf "  ${DIM}(no active claims)${NC}\n"
}

# ── Conflict detection ──────────────────────────────────────────
_show_conflicts() {
  printf "\n  ${BOLD}── File Ownership Conflicts ──────────────────────────────${NC}\n"

  [ ! -f "$CLAIMED_FILE" ] && printf "  ${GREEN}✓ No conflicts (no claims)${NC}\n" && return

  # Build file → owner map in Python (avoids bash 4 assoc array requirement)
  python3 - "$CLAIMED_FILE" << 'PYEOF'
import sys, re

path = sys.argv[1]
file_owners = {}  # file → owner
conflicts = []

with open(path) as f:
    for line in f:
        if not line.startswith('|') or 'Branch' in line or '---' in line:
            continue
        parts = [p.strip() for p in line.split('|')]
        if len(parts) < 4:
            continue
        member, task, files = parts[1], parts[2], parts[3]
        if not member or not task:
            continue
        for fp in [x.strip() for x in files.split(',')]:
            if not fp or fp == '—':
                continue
            if fp in file_owners and file_owners[fp] != member:
                conflicts.append(f"  \033[0;31mCONFLICT\033[0m: {fp}\n    ├ @{file_owners[fp]}\n    └ @{member}")
            else:
                file_owners[fp] = member

if conflicts:
    for c in conflicts:
        print(c)
else:
    print("  \033[0;32m✓ No file conflicts detected\033[0m")
PYEOF
}

# ── Unclaimed tasks available to pick up ───────────────────────
_show_available() {
  local phase="$1"
  local task_dir="$(pwd)/tasks/phase-${phase}"
  [ ! -d "$task_dir" ] && return

  local available=()
  for f in "$task_dir"/TASK-*.md; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == "TASK-000"* ]] && continue
    local fname; fname="$(basename "$f" .md)"
    local status; status="$(_field '\*\*Status:\*\*' "$f")"
    local claimant; claimant="$(_claimant "$fname")"
    if [[ "${status,,}" == "backlog" ]] && [ -z "$claimant" ]; then
      available+=("$fname")
    fi
  done

  if [ ${#available[@]} -gt 0 ]; then
    printf "\n  ${BOLD}Available to claim:${NC}\n"
    printf "  ${CYAN}%s${NC}" "${available[@]}"
    printf "\n  ${DIM}Run: ccclaim TASK-NNN${NC}\n"
  fi
}

# ── Live Backlog MCP query ──────────────────────────────────────
_show_backlog() {
  printf "\n  ${BOLD}── Backlog MCP (live) ────────────────────────────────────${NC}\n"
  if command -v claude &>/dev/null; then
    printf "  Querying Backlog...\n"
    claude --print \
      "Dùng Backlog MCP: get issues của tôi trong project, status != Done, sort by priority. Show table: | ID | Title | Status | Priority |" \
      2>/dev/null || printf "  ${DIM}Backlog MCP không available${NC}\n"
  else
    printf "  ${DIM}claude CLI not found${NC}\n"
  fi
}

# ── Parse args ─────────────────────────────────────────────────
PHASE="$MY_PHASE"
SHOW_ALL=false
SHOW_CONFLICTS=false
SHOW_BACKLOG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase|-p)   PHASE="${2:-$MY_PHASE}"; shift 2 ;;
    --all|-a)     SHOW_ALL=true; shift ;;
    --conflicts|-c) SHOW_CONFLICTS=true; shift ;;
    --backlog|-b) SHOW_BACKLOG=true; shift ;;
    *) shift ;;
  esac
done

# ── Header ─────────────────────────────────────────────────────
proj="$(basename "$(pwd)")"
active_task="$(_member activeTask)"

printf "\n"
printf "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${BOLD}  %s${NC}  Phase %s  Sprint %s\n" "$proj" "$PHASE" "$MY_SPRINT"
[ -n "$MY_NAME" ] && printf "  ${DIM}  %s${NC}" "$MY_NAME"
[ -n "$active_task" ] && printf "${DIM} → active: ${CYAN}%s${NC}" "$active_task"
printf "\n"
printf "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── Tasks ──────────────────────────────────────────────────────
if $SHOW_ALL; then
  for pd in "$(pwd)/tasks/phase-"*/; do
    pnum="$(basename "$pd" | sed 's/phase-//')"
    printf "\n  ${BOLD}── Phase %s ─────────────────────────────────────────────${NC}\n" "$pnum"
    _show_phase "$pnum"
  done
else
  printf "\n  ${BOLD}── Phase %s Tasks ───────────────────────────────────────${NC}\n" "$PHASE"
  _show_phase "$PHASE"
  _show_available "$PHASE"
fi

_show_claims
$SHOW_CONFLICTS && _show_conflicts
$SHOW_BACKLOG && _show_backlog

printf "\n  ${DIM}ccme | ccclaim TASK-NNN | ccunclaim TASK-NNN | cctasks --backlog${NC}\n"
printf "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
