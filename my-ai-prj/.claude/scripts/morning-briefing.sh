#!/usr/bin/env bash
# morning-briefing.sh — Daily briefing cho project
# Crontab: 0 8 * * 1-5 bash /path/to/.claude/scripts/morning-briefing.sh

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Load .env nếu có
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"
[ -f "$PROJECT_DIR/.env" ]       && source "$PROJECT_DIR/.env"

# Đọc context files
memory_context=""
for f in user.md decisions.md preferences.md; do
  [ -f "$PROJECT_DIR/memory/$f" ] && \
    memory_context="$memory_context\n\n## $f\n$(cat "$PROJECT_DIR/memory/$f")"
done

active_todos=""
[ -f "$PROJECT_DIR/todos/active.md" ] && \
  active_todos="$(cat "$PROJECT_DIR/todos/active.md")"

# Tạo briefing qua Claude CLI
briefing="$(claude --print "
Bạn là assistant cho project '$PROJECT_NAME'.

Context:
$memory_context

Active todos:
$active_todos

Tạo morning briefing ngắn gọn (không quá 300 từ):
1. Tóm tắt đang làm gì (dựa vào memory và todos)
2. 3 priorities cho hôm nay — cụ thể và actionable
3. Blockers hoặc risks cần chú ý (nếu có)

Format: plain text, không dùng markdown phức tạp.
" 2>/dev/null || echo "⚠️ Không thể tạo briefing — kiểm tra claude CLI")"

# Gửi lên Slack nếu có webhook
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  payload="{\"text\":\"*🌅 Morning Briefing — $PROJECT_NAME*\n$(date '+%A, %d/%m/%Y')\n\n$briefing\"}"
  curl -s -X POST -H 'Content-type: application/json' \
    --data "$payload" "$SLACK_WEBHOOK_URL" > /dev/null
  echo "✅ Briefing đã gửi lên Slack"
else
  echo ""
  echo "🌅 Morning Briefing — $PROJECT_NAME ($(date '+%d/%m/%Y'))"
  echo "────────────────────────────────────────"
  echo "$briefing"
  echo "────────────────────────────────────────"
  echo "⚠️  SLACK_WEBHOOK_URL chưa set — briefing chỉ hiện ở terminal"
fi
