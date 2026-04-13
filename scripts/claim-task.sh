#!/usr/bin/env bash
# scripts/claim-task.sh — Claim files/modules + sync Backlog qua MCP
#
# Usage:
#   bash claim-task.sh <issue-key> <path1> [path2 ...]
#   bash claim-task.sh --unclaim [issue-key]
#   bash claim-task.sh --unclaim-stale

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

# Load .env.local
[ -f "$SCRIPT_DIR/.env.local" ] && source "$SCRIPT_DIR/.env.local"
[ -f "$(pwd)/.env.local" ]      && source "$(pwd)/.env.local"

CLAIMED_FILE="$SCRIPT_DIR/todos/claimed.md"

# ─── Lấy thông tin member ────────────────────────────────────────
MEMBER="$(git config user.name 2>/dev/null || echo "${USER:-unknown}")"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-branch")"
CLAIM_TIME="$(date '+%Y-%m-%d %H:%M')"
ETA="${CLAIM_ETA:-EOD}"

# ─── Resilient Backlog sync ───────────────────────────────────────
_sync_to_backlog() {
  local task_ref="$1" status="$2" comment="$3"
  [[ "$task_ref" =~ ^[A-Z]+-[0-9]+$ ]] || return 0
  if command -v claude >/dev/null 2>&1; then
    claude --print \
      "Dùng Backlog MCP: 1. Update issue $task_ref sang status '$status' 2. Add comment: $comment" \
      2>/dev/null && ok "Backlog $task_ref → $status" && return 0
    warn "Backlog sync thất bại — claim đã ghi vào claimed.md (sync thủ công sau)"
  else
    warn "claude CLI không có — ghi file-only. Sync Backlog thủ công sau."
  fi
}

# ─── Stale claim detection (>24h) ────────────────────────────────
_check_stale_claims() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0
  local now; now=$(date +%s)
  while IFS='|' read -r _ member task _ _ timestamp _; do
    [[ "$task" == *"Branch/Task"* ]] && continue
    local ts; ts="${timestamp// /}"
    [[ -z "$ts" ]] && continue
    local claim_ts
    claim_ts=$(date -j -f "%Y-%m-%d %H:%M" "$ts" +%s 2>/dev/null || \
               date -d "$ts" +%s 2>/dev/null || echo 0)
    local age=$(( (now - claim_ts) / 3600 ))
    if [[ $age -gt 24 ]]; then
      warn "Stale claim: ${task// /} by ${member// /} (${age}h ago)"
    fi
  done < "$file"
}

# ─── Mass-release stale claims (>24h) ────────────────────────────
_unclaim_stale_claims() {
  local file="$1"
  [[ ! -f "$file" ]] && { echo "claimed.md không tồn tại"; return 0; }
  local now; now=$(date +%s)
  local removed=0
  local tmp; tmp=$(mktemp)
  while IFS= read -r line; do
    local keep=true
    if [[ "$line" == \|* && "$line" != *"Branch/Task"* && "$line" != *"---"* ]]; then
      local ts; ts=$(echo "$line" | awk -F'|' '{print $5}' | xargs)
      if [[ -n "$ts" ]]; then
        local claim_ts
        claim_ts=$(date -j -f "%Y-%m-%d %H:%M" "$ts" +%s 2>/dev/null || \
                   date -d "$ts" +%s 2>/dev/null || echo 0)
        local age=$(( (now - claim_ts) / 3600 ))
        if [[ $age -gt 24 ]]; then
          keep=false
          removed=$(( removed + 1 ))
        fi
      fi
    fi
    if $keep; then echo "$line" >> "$tmp"; fi
  done < "$file"
  mv "$tmp" "$file"
  ok "Đã release $removed stale claims (>24h)"
}

# ─── Unclaim ─────────────────────────────────────────────────────
unclaim_task() {
  local task_ref="${1:-}"
  local member
  member="$(git config user.name 2>/dev/null || echo "${USER:-unknown}")"
  local claimed_file="$SCRIPT_DIR/todos/claimed.md"

  if [[ ! -f "$claimed_file" ]]; then
    echo "claimed.md không tồn tại"; return 1
  fi

  if [[ -z "$task_ref" ]]; then
    echo "Claims của @$member:"
    grep "$member" "$claimed_file" 2>/dev/null || echo "  (không có)"
    echo ""
    printf "Nhập branch/task-id cần unclaim (hoặc 'all'): "
    read -r task_ref < /dev/tty 2>/dev/null || read -r task_ref
  fi

  if [[ "$task_ref" == "all" ]]; then
    grep -v "$member" "$claimed_file" > "${claimed_file}.tmp" || true
    mv "${claimed_file}.tmp" "$claimed_file"
    ok "Đã release tất cả claims của @$member"
  else
    grep -v "$task_ref" "$claimed_file" > "${claimed_file}.tmp" 2>/dev/null || \
      cp "$claimed_file" "${claimed_file}.tmp"
    mv "${claimed_file}.tmp" "$claimed_file"
    ok "Đã release claim: $task_ref"
    _sync_to_backlog "$task_ref" "Done" \
      "🤖 [team-claude-kit] @$member hoàn thành và release claim"
  fi

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  git add "$claimed_file" 2>/dev/null
  git commit -m "chore: @$member releases claim ($task_ref) [skip ci]" \
    --no-verify 2>/dev/null || true
  git push origin "$branch" --quiet 2>/dev/null || \
    warn "Push thất bại — chạy git push thủ công"
}

# ─── Parse args ──────────────────────────────────────────────────
# Nếu script được gọi trực tiếp với tên unclaim-task.sh
if [[ "$(basename "$0")" == "unclaim-task.sh" ]]; then
  unclaim_task "$@"
  exit 0
fi

case "${1:-}" in
  --unclaim-stale)
    _unclaim_stale_claims "$CLAIMED_FILE"
    exit 0 ;;
  --unclaim)
    shift
    unclaim_task "$@"
    exit 0 ;;
esac

# ─── Claim mode ──────────────────────────────────────────────────
TASK_REF="${1:-}"
shift || true
PATHS=("$@")

if [[ -z "$TASK_REF" || ${#PATHS[@]} -eq 0 ]]; then
  echo "Usage:"
  echo "  bash claim-task.sh <task-id> <path1> [path2 ...]"
  echo "  bash claim-task.sh --unclaim [task-id]"
  echo "  bash claim-task.sh --unclaim-stale"
  echo "  CLAIM_ETA=Tomorrow bash claim-task.sh AUTH-123 src/auth/"
  exit 1
fi

# ─── Init claimed.md nếu chưa có ─────────────────────────────────
mkdir -p "$(dirname "$CLAIMED_FILE")"
if [[ ! -f "$CLAIMED_FILE" ]]; then
  cat > "$CLAIMED_FILE" << 'EOF'
# Claimed Tasks

> Claim file/module trước khi làm việc để tránh conflict.
> Unclaim ngay khi xong: ccunclaim

| Member | Branch/Task | Files/Modules | Claimed at | ETA |
|--------|-------------|---------------|------------|-----|
EOF
fi

# ─── Kiểm tra conflict với claims hiện tại ───────────────────────
CONFLICTS=()
for path in "${PATHS[@]}"; do
  while IFS= read -r line; do
    [[ "$line" != \|* ]] && continue
    [[ "$line" == *"Branch/Task"* ]] && continue
    [[ "$line" == *"---"* ]] && continue
    if echo "$line" | grep -q "$path"; then
      existing_member="$(echo "$line" | awk -F'|' '{print $2}' | xargs)"
      existing_task="$(echo "$line" | awk -F'|' '{print $3}' | xargs)"
      if [[ "$existing_member" != "$MEMBER" ]]; then
        CONFLICTS+=("$path → đang được @$existing_member claim ($existing_task)")
      fi
    fi
  done < "$CLAIMED_FILE"
done

# ─── Báo conflict nếu có ─────────────────────────────────────────
if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  warn "⚠️  Phát hiện conflict:"
  for c in "${CONFLICTS[@]}"; do
    warn "   $c"
  done
  echo ""
  printf "${YELLOW}Vẫn tiếp tục claim? (y/N)${NC} " > /dev/tty 2>/dev/null || \
  printf "Vẫn tiếp tục claim? (y/N) "
  read -r answer < /dev/tty 2>/dev/null || read -r answer
  [[ "$answer" != [yY] ]] && { echo "Đã hủy."; exit 0; }
fi

# ─── Thêm claim vào bảng ─────────────────────────────────────────
PATHS_STR="$(IFS=', '; echo "${PATHS[*]}")"
NEW_ROW="| $MEMBER | $TASK_REF | $PATHS_STR | $CLAIM_TIME | $ETA |"
echo "$NEW_ROW" >> "$CLAIMED_FILE"

ok "Đã claim: $PATHS_STR"
ok "Member  : @$MEMBER | Branch: $BRANCH | ETA: $ETA"

# ─── Sync lên Backlog ─────────────────────────────────────────────
info "Syncing $TASK_REF lên Backlog..."
_sync_to_backlog "$TASK_REF" "In Progress" \
  "🤖 [team-claude-kit] @$MEMBER bắt đầu làm trên branch \`$BRANCH\`. Files: $PATHS_STR"

echo ""
echo "Unclaim khi xong: ccunclaim \"$TASK_REF\""

# ─── Auto-commit claimed.md ───────────────────────────────────────
if ! git diff --quiet "$CLAIMED_FILE" 2>/dev/null; then
  git add "$CLAIMED_FILE" 2>/dev/null
  git commit -m "chore: @$MEMBER claims $PATHS_STR [skip ci]" \
    --no-verify 2>/dev/null || true
  git push origin "$BRANCH" --quiet 2>/dev/null || \
    warn "Push claimed.md thất bại — chạy git push thủ công"
fi
