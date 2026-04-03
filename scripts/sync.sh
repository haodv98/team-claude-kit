#!/bin/bash
# sync.sh — Pull updates từ kit về machine
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_HOME="$HOME/.claude"
MODE="${1:-both}"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

info "Kiểm tra update từ remote..."
cd "$KIT_DIR"
git fetch origin --quiet 2>/dev/null || warn "Không có remote hoặc offline"
BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "0")
if [ "$BEHIND" -gt "0" ]; then
  echo "  Có $BEHIND commit mới."
  read -p "  Pull? (Y/n): " DO_PULL
  [[ "$DO_PULL" != "n" ]] && git pull origin main --quiet && log "Kit updated"
else
  log "Kit đang ở phiên bản mới nhất"
fi
cd - > /dev/null

if [[ "$MODE" != "--project" ]]; then
  info "Sync ~/.claude..."
  rsync -av --update "$KIT_DIR/claude/agents/" "$CLAUDE_HOME/agents/" > /dev/null
  rsync -av --update "$KIT_DIR/claude/skills/" "$CLAUDE_HOME/skills/" > /dev/null
  rsync -av --update "$KIT_DIR/claude/commands/" "$CLAUDE_HOME/commands/" > /dev/null
  rsync -av --update "$KIT_DIR/claude/hooks/" "$CLAUDE_HOME/hooks/" > /dev/null
  log "Global ~/.claude synced"
fi

if [[ "$MODE" == "--push" ]]; then
  echo ""; echo "Đóng góp vào kit:"
  echo "1) Command  2) Agent  3) Skill  4) CLAUDE.md"
  read -p "Chọn: " TYPE
  case $TYPE in
    1) SRC=".claude/commands"; DST="$KIT_DIR/claude/commands" ;;
    2) SRC=".claude/agents";   DST="$KIT_DIR/claude/agents" ;;
    3) SRC=".claude/skills";   DST="$KIT_DIR/claude/skills" ;;
    4) diff "CLAUDE.md" "$KIT_DIR/claude/CLAUDE.md" || true
       read -p "Copy CLAUDE.md vào kit? (y/N): " OK
       [[ "$OK" == "y" ]] && cp "CLAUDE.md" "$KIT_DIR/claude/CLAUDE.md" && log "Copied"
       echo "  cd $KIT_DIR && git add . && git commit -m 'sync' && git push"; exit 0 ;;
  esac
  ls "$SRC/" 2>/dev/null
  read -p "Tên file: " FILE
  cp "$SRC/$FILE" "$DST/$FILE" && log "Pushed $FILE"
  echo "  cd $KIT_DIR && git add . && git commit -m 'feat: add $FILE' && git push"
fi

echo ""; log "Sync hoàn tất"
