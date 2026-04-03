#!/bin/bash
# session-timer.sh — Cảnh báo trước khi hết quota 5 tiếng
SESSION_DURATION=$((5 * 60 * 60))
WARN_BEFORE=600
SESSION_FILE="$HOME/.claude/sessions/.current-timer"

if [[ "$1" == "status" ]]; then
  [[ ! -f "$SESSION_FILE" ]] && echo "Không có session đang chạy" && exit 0
  START=$(cat "$SESSION_FILE")
  ELAPSED=$(( $(date +%s) - START ))
  LEFT=$(( SESSION_DURATION - ELAPSED ))
  printf "Đã dùng: %d phút | Còn lại: %d phút\n" $((ELAPSED/60)) $((LEFT/60))
  exit 0
fi

mkdir -p "$(dirname "$SESSION_FILE")"
date +%s > "$SESSION_FILE"
RESET_TIME=$(date -v+${SESSION_DURATION}S '+%H:%M' 2>/dev/null || date -d "+${SESSION_DURATION} seconds" '+%H:%M')
echo "⏱  Session bắt đầu — reset lúc $RESET_TIME"

notify() {
  local msg="$1" title="$2" sound="${3:-Glass}"
  command -v osascript &>/dev/null && \
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"$sound\"" 2>/dev/null || \
    echo "$title: $msg"
}

sleep $((SESSION_DURATION - WARN_BEFORE))
notify "Còn 10 phút — /wrap-session ngay!" "Claude Code ⏰" "Glass"
echo ""; echo "⚠️  CÒN 10 PHÚT — chạy /wrap-session ngay!"
sleep 300
notify "Còn 5 phút! Lưu ngay!" "Claude Code 🔴" "Basso"
echo "🔴 CÒN 5 PHÚT!"
sleep 240
notify "Còn 1 phút!" "Claude Code 💀" "Sosumi"
echo "💀 CÒN 1 PHÚT!"
sleep 60
notify "Session reset. Bắt đầu session mới!" "Claude Code ✅" "Hero"
echo "✅ Reset — mở session mới với ccstart"
rm -f "$SESSION_FILE"
