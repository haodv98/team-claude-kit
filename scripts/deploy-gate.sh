#!/usr/bin/env bash
# scripts/deploy-gate.sh — Staging/Production deploy gate: new | list | open | status
# Alias: ccdeploy
#
# Usage:
#   ccdeploy new staging              # tạo staging deploy checklist
#   ccdeploy new production           # tạo production deploy checklist
#   ccdeploy list                     # liệt kê tất cả deploys
#   ccdeploy open [env] [deploy-N]    # mở deploy record mới nhất
#   ccdeploy status                   # bảng trạng thái tất cả deploys

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

[ -f "$SCRIPT_DIR/.env.local" ] && source "$SCRIPT_DIR/.env.local"
[ -f "$(pwd)/.env.local" ]      && source "$(pwd)/.env.local"

DEPLOY_ROOT="$(pwd)/deploys"
AUDIT_ROOT="$(pwd)/audits"
MEMBER_FILE="$(pwd)/.claude/member.local.json"
PROJECT_NAME="$(basename "$(pwd)")"

VALID_ENVS=("staging" "production")

# ─── usage ───────────────────────────────────────────────────────
usage() {
  cat << 'EOF'
ccdeploy — Staging/Production deploy gate

Usage:
  ccdeploy new staging              Tạo staging deploy checklist
  ccdeploy new production           Tạo production deploy checklist
  ccdeploy list                     Liệt kê tất cả deploy records
  ccdeploy open [staging|production] Mở deploy record mới nhất
  ccdeploy status                   Bảng trạng thái tất cả deploys

Examples:
  ccdeploy new staging
  ccdeploy new production
  ccdeploy open staging
  ccdeploy status

Playbook: docs/DEPLOY-GUIDE.md
EOF
}

# ─── Validate environment arg ─────────────────────────────────────
_validate_env() {
  local env="$1"
  for v in "${VALID_ENVS[@]}"; do
    [ "$env" = "$v" ] && return 0
  done
  err_log "Environment không hợp lệ: '$env'. Dùng: staging | production"
  exit 1
}

# ─── Default sprint từ member.local.json ────────────────────────
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

# ─── Latest audit file trong project ─────────────────────────────
_latest_audit() {
  local f
  f="$(find "$AUDIT_ROOT" -name "*.md" 2>/dev/null | grep -v .gitkeep | sort | tail -1 || true)"
  if [ -n "$f" ]; then
    # Return relative path từ project root
    echo "${f#$(pwd)/}"
  else
    echo "[chưa có audit — chạy ccaudit new]"
  fi
}

# ─── Latest staging deploy file ──────────────────────────────────
_latest_staging_deploy() {
  local f
  f="$(find "$DEPLOY_ROOT/staging" -name "*.md" 2>/dev/null | grep -v .gitkeep | sort | tail -1 || true)"
  if [ -n "$f" ]; then
    echo "${f#$(pwd)/}"
  else
    echo "[chưa có staging deploy — chạy ccdeploy new staging]"
  fi
}

# ─── Slugify ─────────────────────────────────────────────────────
_slugify() {
  python3 -c "
import re, sys
s = sys.argv[1].lower()
s = re.sub(r'[^a-z0-9]+', '-', s)
s = s.strip('-')
print(s[:40])
" "$1"
}

# ─── Prompt wizard ────────────────────────────────────────────────
_prompt_deploy_fields() {
  local env="$1"
  local default_sprint; default_sprint="$(_default_sprint)"
  local default_deployer; default_deployer="$(git config user.name 2>/dev/null || echo "${USER:-Deployer}")"

  _tty ""

  printf "  ${CYAN}→${NC}  Sprint # [%s]: " "$default_sprint" > /dev/tty 2>/dev/null || \
  printf "  Sprint # [%s]: " "$default_sprint"
  IFS= read -r SPRINT_NUMBER < /dev/tty 2>/dev/null || IFS= read -r SPRINT_NUMBER
  SPRINT_NUMBER="${SPRINT_NUMBER:-$default_sprint}"

  printf "  ${CYAN}→${NC}  Version (e.g. 1.2.3): " > /dev/tty 2>/dev/null || \
  printf "  Version (e.g. 1.2.3): "
  IFS= read -r VERSION < /dev/tty 2>/dev/null || IFS= read -r VERSION
  VERSION="${VERSION:-0.0.1}"

  printf "  ${CYAN}→${NC}  Deployer [%s]: " "$default_deployer" > /dev/tty 2>/dev/null || \
  printf "  Deployer [%s]: " "$default_deployer"
  IFS= read -r DEPLOYER < /dev/tty 2>/dev/null || IFS= read -r DEPLOYER
  DEPLOYER="${DEPLOYER:-$default_deployer}"

  DATE="$(date '+%Y-%m-%d')"
  AUDIT_FILE="$(_latest_audit)"

  if [ "$env" = "production" ]; then
    STAGING_DEPLOY_FILE="$(_latest_staging_deploy)"
    _tty ""
    info "Staging deploy ref: $STAGING_DEPLOY_FILE"
  fi
}

# ─── Render template ─────────────────────────────────────────────
_render_template() {
  local env="$1"
  local dest="$2"
  local tmpl="$SCRIPT_DIR/templates/deploy/${env}.md"

  [ ! -f "$tmpl" ] && { err_log "Template không tìm thấy: $tmpl"; exit 1; }

  if [ "${DRY_RUN:-false}" = true ]; then
    info "[dry-run] render $tmpl → $dest"
    return 0
  fi

  local staging_ref="${STAGING_DEPLOY_FILE:-N/A}"

  python3 - "$tmpl" "$dest" \
    "$PROJECT_NAME" "$VERSION" "$SPRINT_NUMBER" "$DEPLOYER" "$DATE" \
    "$AUDIT_FILE" "$staging_ref" << 'PYEOF'
import sys

src, dest = sys.argv[1], sys.argv[2]
project, version, sprint, deployer, date, audit_file, staging_file = sys.argv[3:10]

with open(src) as f:
    content = f.read()

for key, val in {
    '{{PROJECT_NAME}}':        project,
    '{{VERSION}}':             version,
    '{{SPRINT_NUMBER}}':       sprint,
    '{{DEPLOYER}}':            deployer,
    '{{DATE}}':                date,
    '{{AUDIT_FILE}}':          audit_file,
    '{{STAGING_DEPLOY_FILE}}': staging_file,
}.items():
    content = content.replace(key, val)

with open(dest, 'w') as f:
    f.write(content)
PYEOF
}

# ─── cmd: new ────────────────────────────────────────────────────
cmd_new() {
  local env="${1:-}"
  [ -z "$env" ] && { err_log "Chỉ định environment: ccdeploy new staging | production"; exit 1; }
  _validate_env "$env"

  header "Tạo Deploy Gate — $PROJECT_NAME → ${env^^}"

  # Extra guard cho production
  if [ "$env" = "production" ]; then
    _tty ""
    warn "Deploy lên PRODUCTION. Kiểm tra staging đã stable trước."
    if ! ask "Staging đã deploy và stable ≥24h?"; then
      err_log "Deploy production bị block. Deploy staging trước: ccdeploy new staging"
      exit 1
    fi
  fi

  _prompt_deploy_fields "$env"

  local slug; slug="$(_slugify "v${VERSION}")"
  local dest_dir="$DEPLOY_ROOT/${env}"
  local dest="${dest_dir}/${DATE}-${slug}.md"

  if [ -f "$dest" ]; then
    warn "File đã tồn tại: deploys/${env}/${DATE}-${slug}.md"
    if ! ask "Ghi đè?"; then
      info "Đã hủy"
      return 0
    fi
  fi

  mkdir -p "$dest_dir"
  _render_template "$env" "$dest"

  ok "Deploy gate → deploys/${env}/${DATE}-${slug}.md"
  _tty ""
  _tty "  Bước tiếp theo:"
  _tty "    1.  ccdeploy open ${env}        — mở và tick checklist"
  _tty "    2.  Làm theo docs/DEPLOY-GUIDE.md"
  _tty "    3.  ccdeploy status              — xem trạng thái tất cả deploys"
  _tty ""
}

# ─── Walk deploy tree ─────────────────────────────────────────────
_walk_deploys() {
  if [ ! -d "$DEPLOY_ROOT" ]; then
    _tty "  (chưa có deploys/ — chạy: ccdeploy new staging)"
    return 0
  fi

  local count=0
  for env in staging production; do
    local env_dir="$DEPLOY_ROOT/$env"
    [ -d "$env_dir" ] || continue
    _tty ""
    _tty "  ${BOLD}${BLUE}▸ $env${NC}"
    for f in "$env_dir"*.md; do
      [ -f "$f" ] || continue
      local fname; fname="$(basename "$f")"
      [[ "$fname" == .gitkeep ]] && continue
      local verdict
      verdict="$(grep -m1 'DEPLOYED\|ROLLED BACK\|BLOCKED\|PENDING' "$f" 2>/dev/null | \
                 grep -o 'DEPLOYED\|ROLLED BACK\|BLOCKED\|PENDING' | head -1 || echo "—")"
      local color="$NC"
      [[ "$verdict" == "DEPLOYED" ]]    && color="$GREEN"
      [[ "$verdict" == "PENDING" ]]     && color="$YELLOW"
      [[ "$verdict" == "ROLLED BACK" ]] && color="$RED"
      [[ "$verdict" == "BLOCKED" ]]     && color="$RED"
      _tty "    ${fname}  ${color}[${verdict}]${NC}"
      ((count++)) || true
    done
  done

  _tty ""
  [ $count -eq 0 ] && _tty "  (không có deploy records — chạy: ccdeploy new staging)"
  [ $count -gt 0 ] && info "$count deploy record(s)"
}

# ─── cmd: list ───────────────────────────────────────────────────
cmd_list() {
  header "Deploy Records — $PROJECT_NAME"
  _walk_deploys
}

# ─── Resolve latest deploy file ──────────────────────────────────
_resolve_deploy_target() {
  local env="${1:-}"

  if [ -n "$env" ]; then
    _validate_env "$env"
    local search_dir="$DEPLOY_ROOT/$env"
    if [ ! -d "$search_dir" ]; then
      err_log "Không có deploys cho: $env"
      exit 1
    fi
    local target
    target="$(ls -1 "$search_dir"*.md 2>/dev/null | grep -v .gitkeep | sort | tail -1 || true)"
    if [ -z "$target" ]; then
      err_log "Không có deploy file trong $env"
      exit 1
    fi
    echo "$target"
  else
    # Latest across both envs
    local target
    target="$(find "$DEPLOY_ROOT" -name "*.md" 2>/dev/null | grep -v .gitkeep | sort | tail -1 || true)"
    if [ -z "$target" ]; then
      err_log "Không có deploy records. Chạy: ccdeploy new staging"
      exit 1
    fi
    echo "$target"
  fi
}

# ─── cmd: open ───────────────────────────────────────────────────
cmd_open() {
  local env="${1:-}"
  local target; target="$(_resolve_deploy_target "$env")"
  info "Mở: $(basename "$(dirname "$target")")/$(basename "$target")"
  if [ -n "${EDITOR:-}" ]; then
    $EDITOR "$target"
  elif has bat; then
    bat --paging=always "$target"
  else
    cat "$target"
  fi
}

# ─── Parse deploy status từ files ────────────────────────────────
_parse_deploy_status() {
  python3 - "$@" << 'PYEOF'
import sys, re, os

files = sys.argv[1:]
rows = []

for path in files:
    try:
        with open(path) as f:
            content = f.read()

        parts = path.split(os.sep)
        env = next((p for p in parts if p in ('staging', 'production')), '?')
        fname = os.path.basename(path)

        # Version — from file header (more reliable than filename)
        m = re.search(r'## .+ — v([\d\.]+)', content)
        if not m:
            m = re.search(r'v(\d+\.\d+[\.\d]*)', fname)
            version = 'v' + m.group(1).replace('-', '.') if m else '—'
        else:
            version = 'v' + m.group(1)

        # Deployer
        m = re.search(r'\*\*Deployer:\*\*\s*(.+)', content)
        deployer = m.group(1).strip() if m else '—'

        # Date
        m = re.search(r'\*\*Date:\*\*\s*(.+)', content)
        date = m.group(1).strip() if m else '—'

        # Verdict
        vm = re.search(r'\*\*Deploy Decision:\*\*[^*]*\*\*([A-Z ]+)\*\*', content)
        verdict = vm.group(1).strip() if vm else '—'
        if verdict == '—':
            # Fallback: scan for verdict keywords
            vm2 = re.search(r'(?:DEPLOYED|ROLLED BACK|BLOCKED|PENDING)', content)
            verdict = vm2.group(0) if vm2 else '—'

        rows.append((env, version, deployer, date, verdict))
    except Exception as e:
        sys.stderr.write(f"Skip {path}: {e}\n")

# Sort: staging before production, then by date
order = {'staging': 0, 'production': 1}
rows.sort(key=lambda x: (order.get(x[0], 9), x[3]))

for r in rows:
    print('|'.join(r))
PYEOF
}

# ─── In status table ──────────────────────────────────────────────
_print_status_table() {
  local rows="$1"

  _tty ""
  _tty "  ${BOLD}Env          Version    Deployer              Date        Verdict${NC}"
  _tty "  ───────────  ─────────  ────────────────────  ──────────  ─────────────────"

  while IFS='|' read -r env version deployer date verdict; do
    [ -z "$env" ] && continue
    local color="$NC"
    [[ "$verdict" == "DEPLOYED" ]]    && color="$GREEN"
    [[ "$verdict" == "PENDING" ]]     && color="$YELLOW"
    [[ "$verdict" == *"ROLLED"* ]]    && color="$RED"
    [[ "$verdict" == "BLOCKED" ]]     && color="$RED"

    printf "  %-11s  %-9s  %-20s  %-10s  ${color}%s${NC}\n" \
      "$env" "$version" "$deployer" "$date" "$verdict" > /dev/tty 2>/dev/null || \
    printf "  %-11s  %-9s  %-20s  %-10s  %s\n" \
      "$env" "$version" "$deployer" "$date" "$verdict"
  done <<< "$rows"

  _tty ""
}

# ─── cmd: status ─────────────────────────────────────────────────
cmd_status() {
  header "Deploy Status — $PROJECT_NAME"

  if [ ! -d "$DEPLOY_ROOT" ]; then
    warn "Không có deploys. Chạy: ccdeploy new staging"
    return 0
  fi

  local files=()
  while IFS= read -r f; do
    [[ "$f" == *.gitkeep ]] && continue
    files+=("$f")
  done < <(find "$DEPLOY_ROOT" -name "*.md" 2>/dev/null | sort)

  if [ ${#files[@]} -eq 0 ]; then
    warn "Không tìm thấy deploy records"
    return 0
  fi

  local rows; rows="$(_parse_deploy_status "${files[@]}")"

  if [ -z "$rows" ]; then
    warn "Không parse được status — hãy điền Verdict vào deploy files"
    return 0
  fi

  _print_status_table "$rows"
}

# ─── Dispatch ────────────────────────────────────────────────────
case "${1:-}" in
  new)    shift; cmd_new "$@" ;;
  list)   shift; cmd_list "$@" ;;
  open)   shift; cmd_open "$@" ;;
  status) shift; cmd_status "$@" ;;
  -h|--help|"") usage ;;
  *) err_log "Unknown subcommand: $1"; echo ""; usage; exit 1 ;;
esac
