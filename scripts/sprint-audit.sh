#!/usr/bin/env bash
# scripts/sprint-audit.sh — Sprint-end audit lifecycle: new | list | open | summary
# Alias: ccaudit
#
# Usage:
#   ccaudit new                     # wizard: tạo audit report cho sprint hiện tại
#   ccaudit list                    # liệt kê tất cả audits trong project
#   ccaudit open [sprint-N]         # mở audit mới nhất (hoặc sprint cụ thể)
#   ccaudit summary [--sprint N]    # bảng điểm tất cả audits

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

[ -f "$SCRIPT_DIR/.env.local" ] && source "$SCRIPT_DIR/.env.local"
[ -f "$(pwd)/.env.local" ]      && source "$(pwd)/.env.local"

AUDIT_ROOT="$(pwd)/audits"
TEMPLATE_FILE="$SCRIPT_DIR/templates/audit/template.md"
MEMBER_FILE="$(pwd)/.claude/member.local.json"
PROJECT_NAME="$(basename "$(pwd)")"

# ─── usage ───────────────────────────────────────────────────────
usage() {
  cat << 'EOF'
ccaudit — Sprint-end audit tool (QA Team Lead)

Usage:
  ccaudit new                  Tạo audit report cho sprint hiện tại
  ccaudit list                 Liệt kê tất cả audits trong project
  ccaudit open [sprint-N]      Mở audit mới nhất (hoặc sprint cụ thể)
  ccaudit summary [--sprint N] Bảng điểm tất cả audits

Examples:
  ccaudit new
  ccaudit open sprint-2
  ccaudit summary --sprint 1
  ccaudit summary             # tất cả sprints

Playbook: docs/SPRINT-AUDIT-GUIDE.md
EOF
}

# ─── Slugify string → kebab-case ─────────────────────────────────
_slugify() {
  python3 -c "
import re, sys
s = sys.argv[1].lower()
s = re.sub(r'[^a-z0-9]+', '-', s)
s = s.strip('-')
print(s[:60])
" "$1"
}

# ─── Lấy sprint number từ member.local.json ──────────────────────
_default_sprint() {
  if [ -f "$MEMBER_FILE" ]; then
    python3 -c "
import json
try:
    d = json.load(open('$MEMBER_FILE'))
    print(d.get('sprint', 1))
except:
    print(1)
" 2>/dev/null || echo "1"
  else
    echo "1"
  fi
}

# ─── Prompt wizard ────────────────────────────────────────────────
_prompt_audit_fields() {
  local default_sprint; default_sprint="$(_default_sprint)"
  local default_reviewer; default_reviewer="$(git config user.name 2>/dev/null || echo "${USER:-QA Lead}")"

  _tty ""

  printf "  ${CYAN}→${NC}  Sprint # [%s]: " "$default_sprint" > /dev/tty 2>/dev/null || \
  printf "  Sprint # [%s]: " "$default_sprint"
  IFS= read -r SPRINT_NUMBER < /dev/tty 2>/dev/null || IFS= read -r SPRINT_NUMBER
  SPRINT_NUMBER="${SPRINT_NUMBER:-$default_sprint}"

  printf "  ${CYAN}→${NC}  PR Title: " > /dev/tty 2>/dev/null || \
  printf "  PR Title: "
  IFS= read -r PR_TITLE < /dev/tty 2>/dev/null || IFS= read -r PR_TITLE
  PR_TITLE="${PR_TITLE:-Sprint ${SPRINT_NUMBER} Review}"

  printf "  ${CYAN}→${NC}  Sprint Milestone [%s]: " "$PR_TITLE" > /dev/tty 2>/dev/null || \
  printf "  Sprint Milestone [%s]: " "$PR_TITLE"
  IFS= read -r SPRINT_MILESTONE < /dev/tty 2>/dev/null || IFS= read -r SPRINT_MILESTONE
  SPRINT_MILESTONE="${SPRINT_MILESTONE:-$PR_TITLE}"

  printf "  ${CYAN}→${NC}  Reviewer [%s]: " "$default_reviewer" > /dev/tty 2>/dev/null || \
  printf "  Reviewer [%s]: " "$default_reviewer"
  IFS= read -r REVIEWER < /dev/tty 2>/dev/null || IFS= read -r REVIEWER
  REVIEWER="${REVIEWER:-$default_reviewer}"

  DATE="$(date '+%Y-%m-%d')"
}

# ─── Render template với variable substitution ───────────────────
_render_template() {
  local dest="$1"

  [ ! -f "$TEMPLATE_FILE" ] && { err_log "Template không tìm thấy: $TEMPLATE_FILE"; exit 1; }

  if [ "${DRY_RUN:-false}" = true ]; then
    info "[dry-run] render $TEMPLATE_FILE → $dest"
    return 0
  fi

  python3 - "$TEMPLATE_FILE" "$dest" \
    "$PROJECT_NAME" "$SPRINT_NUMBER" "$SPRINT_MILESTONE" "$PR_TITLE" "$REVIEWER" "$DATE" << 'PYEOF'
import sys

src, dest = sys.argv[1], sys.argv[2]
project, sprint, milestone, pr_title, reviewer, date = sys.argv[3:9]

with open(src, 'r') as f:
    content = f.read()

for key, val in {
    '{{PROJECT_NAME}}':     project,
    '{{SPRINT_NUMBER}}':    sprint,
    '{{SPRINT_MILESTONE}}': milestone,
    '{{PR_TITLE}}':         pr_title,
    '{{REVIEWER}}':         reviewer,
    '{{DATE}}':             date,
}.items():
    content = content.replace(key, val)

with open(dest, 'w') as f:
    f.write(content)
PYEOF
}

# ─── cmd: new ────────────────────────────────────────────────────
cmd_new() {
  header "Tạo Sprint Audit Report — $PROJECT_NAME"

  if [ ! -f "$TEMPLATE_FILE" ]; then
    err_log "Audit template không tìm thấy: $TEMPLATE_FILE"
    err_log "Cài lại kit: bash bootstrap.sh"
    exit 1
  fi

  _prompt_audit_fields

  local slug; slug="$(_slugify "$PR_TITLE")"
  local dest_dir="$AUDIT_ROOT/sprint-${SPRINT_NUMBER}"
  local dest="$dest_dir/${DATE}-${slug}.md"

  if [ -f "$dest" ]; then
    warn "File đã tồn tại: audits/sprint-${SPRINT_NUMBER}/${DATE}-${slug}.md"
    if ! ask "Ghi đè?"; then
      info "Đã hủy"
      return 0
    fi
  fi

  mkdir -p "$dest_dir"
  _render_template "$dest"

  ok "Audit report → audits/sprint-${SPRINT_NUMBER}/${DATE}-${slug}.md"
  _tty ""
  _tty "  Bước tiếp theo:"
  _tty "    1.  ccaudit open sprint-${SPRINT_NUMBER}   — mở và điền report"
  _tty "    2.  Làm theo docs/SPRINT-AUDIT-GUIDE.md    — step-by-step"
  _tty "    3.  ccaudit summary                        — bảng điểm tổng hợp"
  _tty ""
}

# ─── Walk audit tree ─────────────────────────────────────────────
_walk_audits() {
  if [ ! -d "$AUDIT_ROOT" ]; then
    _tty "  (chưa có audits/ — chạy: ccaudit new)"
    return 0
  fi

  local count=0
  for sprint_dir in "$AUDIT_ROOT"/sprint-*/; do
    [ -d "$sprint_dir" ] || continue
    local sprint_name; sprint_name="$(basename "$sprint_dir")"
    _tty ""
    _tty "  ${BOLD}${BLUE}▸ $sprint_name${NC}"
    for f in "$sprint_dir"*.md; do
      [ -f "$f" ] || continue
      local fname; fname="$(basename "$f")"
      [[ "$fname" == .gitkeep ]] && continue
      local verdict
      verdict="$(grep -m1 'CONDITIONAL APPROVAL\|APPROVED\|REJECTED\|CONDITIONAL' "$f" 2>/dev/null | \
                 grep -o 'CONDITIONAL APPROVAL\|APPROVED\|REJECTED\|CONDITIONAL' | head -1 || echo "—")"
      local color="$NC"
      [[ "$verdict" == "APPROVED" ]]            && color="$GREEN"
      [[ "$verdict" == *"CONDITIONAL"* ]]        && color="$YELLOW"
      [[ "$verdict" == "REJECTED" ]]             && color="$RED"
      _tty "    ${fname}  ${color}[${verdict}]${NC}"
      ((count++)) || true
    done
  done

  _tty ""
  [ $count -eq 0 ] && _tty "  (không có audit file nào — chạy: ccaudit new)"
  [ $count -gt 0 ] && info "$count audit file(s) tìm thấy"
}

# ─── cmd: list ───────────────────────────────────────────────────
cmd_list() {
  header "Audit List — $PROJECT_NAME"
  _walk_audits
}

# ─── Resolve audit target path ───────────────────────────────────
_resolve_audit_target() {
  local spec="${1:-}"
  local search_dir

  if [ -n "$spec" ]; then
    search_dir="$AUDIT_ROOT/$spec"
    if [ ! -d "$search_dir" ]; then
      err_log "Sprint không tìm thấy: $search_dir"
      err_log "Xem danh sách: ccaudit list"
      exit 1
    fi
  else
    search_dir="$(ls -dt "$AUDIT_ROOT"/sprint-*/ 2>/dev/null | head -1 || true)"
    if [ -z "$search_dir" ]; then
      err_log "Không có audits. Chạy: ccaudit new"
      exit 1
    fi
  fi

  local target
  target="$(ls -1 "$search_dir"*.md 2>/dev/null | grep -v '.gitkeep' | sort | tail -1 || true)"
  if [ -z "$target" ]; then
    err_log "Không có audit file trong $(basename "$search_dir")"
    exit 1
  fi
  echo "$target"
}

# ─── cmd: open ───────────────────────────────────────────────────
cmd_open() {
  local spec="${1:-}"
  local target; target="$(_resolve_audit_target "$spec")"
  info "Mở: $(basename "$(dirname "$target")")/$(basename "$target")"
  if [ -n "${EDITOR:-}" ]; then
    $EDITOR "$target"
  elif has bat; then
    bat --paging=always "$target"
  else
    cat "$target"
  fi
}

# ─── Parse scores từ audit files ─────────────────────────────────
_parse_scores() {
  python3 - "$@" << 'PYEOF'
import sys, re, os

files = sys.argv[1:]
rows = []

for path in files:
    try:
        with open(path) as f:
            content = f.read()

        # Sprint từ tên dir
        parts = path.split(os.sep)
        sprint = next((p.replace('sprint-', '') for p in parts if p.startswith('sprint-')), '?')

        # Reviewer
        m = re.search(r'\*\*Reviewer:\*\*\s*(.+)', content)
        reviewer = m.group(1).strip() if m else '—'

        def score(pattern):
            m = re.search(pattern, content)
            return m.group(1) if m else '—'

        code     = score(r'Code Quality Score:\s*(\d+)/100')
        security = score(r'Security Score:\s*(\d+)/100')
        perf     = score(r'Performance Score:\s*(\d+)/100')
        comp     = score(r'Compliance Score:\s*(\d+)/100')

        vm = re.search(r'CONDITIONAL APPROVAL|APPROVED|REJECTED|CONDITIONAL', content)
        verdict = vm.group(0) if vm else '—'

        rows.append((sprint, reviewer, code, security, perf, comp, verdict))
    except Exception as e:
        sys.stderr.write(f"Skip {path}: {e}\n")

for r in sorted(rows, key=lambda x: (len(x[0]), x[0])):
    print('|'.join(r))
PYEOF
}

# ─── In bảng điểm ────────────────────────────────────────────────
_print_score_table() {
  local rows="$1"

  _tty ""
  _tty "  ${BOLD}Sprint  Reviewer              Code  Sec   Perf  Comp  Verdict${NC}"
  _tty "  ──────  ────────────────────  ────  ────  ────  ────  ─────────────────────"

  while IFS='|' read -r sprint reviewer code sec perf comp verdict; do
    [ -z "$sprint" ] && continue
    local color="$NC"
    [[ "$verdict" == "APPROVED" ]]     && color="$GREEN"
    [[ "$verdict" == *"CONDITIONAL"* ]] && color="$YELLOW"
    [[ "$verdict" == "REJECTED" ]]     && color="$RED"

    printf "  %-6s  %-20s  %-4s  %-4s  %-4s  %-4s  ${color}%s${NC}\n" \
      "$sprint" "$reviewer" "$code" "$sec" "$perf" "$comp" "$verdict" > /dev/tty 2>/dev/null || \
    printf "  %-6s  %-20s  %-4s  %-4s  %-4s  %-4s  %s\n" \
      "$sprint" "$reviewer" "$code" "$sec" "$perf" "$comp" "$verdict"
  done <<< "$rows"

  _tty ""
}

# ─── cmd: summary ────────────────────────────────────────────────
cmd_summary() {
  local filter_sprint=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sprint) filter_sprint="sprint-$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  header "Audit Summary — $PROJECT_NAME"

  if [ ! -d "$AUDIT_ROOT" ]; then
    warn "Không có audits. Chạy: ccaudit new"
    return 0
  fi

  local search_root="$AUDIT_ROOT"
  [ -n "$filter_sprint" ] && search_root="$AUDIT_ROOT/$filter_sprint"

  local files=()
  while IFS= read -r f; do
    [[ "$f" == *.gitkeep ]] && continue
    files+=("$f")
  done < <(find "$search_root" -name "*.md" 2>/dev/null | sort)

  if [ ${#files[@]} -eq 0 ]; then
    warn "Không tìm thấy audit files${filter_sprint:+ trong $filter_sprint}"
    return 0
  fi

  local rows; rows="$(_parse_scores "${files[@]}")"

  if [ -z "$rows" ]; then
    warn "Không parse được scores — hãy điền section 'Metrics' vào audit files trước"
    info "Xem hướng dẫn: ccaudit open"
    return 0
  fi

  _print_score_table "$rows"
}

# ─── Dispatch ────────────────────────────────────────────────────
case "${1:-}" in
  new)     shift; cmd_new "$@" ;;
  list)    shift; cmd_list "$@" ;;
  open)    shift; cmd_open "$@" ;;
  summary) shift; cmd_summary "$@" ;;
  -h|--help|"") usage ;;
  *) err_log "Unknown subcommand: $1"; echo ""; usage; exit 1 ;;
esac
