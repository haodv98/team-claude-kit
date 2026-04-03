#!/bin/bash
# install.sh — Onboard machine mới vào team-claude-kit
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_HOME="$HOME/.claude"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo ""; echo "Team Claude Kit — Install"; echo "=========================="

mkdir -p "$CLAUDE_HOME"/{agents,skills,commands,hooks,sessions,rules}

info "Copying agents..."
cp "$KIT_DIR/claude/agents/"*.md "$CLAUDE_HOME/agents/" 2>/dev/null && log "agents ✓" || warn "No agents found"

info "Copying skills..."
cp "$KIT_DIR/claude/skills/"*.md "$CLAUDE_HOME/skills/" 2>/dev/null && log "skills ✓" || warn "No skills found"

info "Copying commands..."
cp "$KIT_DIR/claude/commands/"*.md "$CLAUDE_HOME/commands/" 2>/dev/null && log "commands ✓" || warn "No commands found"

info "Copying hooks..."
cp "$KIT_DIR/claude/hooks/"*.js "$CLAUDE_HOME/hooks/" && chmod +x "$CLAUDE_HOME/hooks/"*.js && log "hooks ✓"

SETTINGS="$CLAUDE_HOME/settings.json"
if [ ! -f "$SETTINGS" ]; then
  cp "$KIT_DIR/claude/settings.json" "$SETTINGS" && log "settings.json created ✓"
else
  warn "settings.json exists — merge thủ công nếu cần"
  echo "   Kit: $KIT_DIR/claude/settings.json"
  echo "   Bạn: $SETTINGS"
fi

info "Installing Context7 MCP..."
if command -v claude &>/dev/null; then
  claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp@latest 2>/dev/null \
    && log "Context7 MCP ✓" || warn "Context7 đã có hoặc lỗi — kiểm tra /mcp"
else
  warn "Claude Code chưa cài. Sau khi cài chạy:"
  echo "   claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp@latest"
fi

ZSHRC="$HOME/.zshrc"
if ! grep -q "# team-claude-kit" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" << ALIASES

# team-claude-kit
alias ccstart='bash $KIT_DIR/scripts/session-timer.sh & claude'
alias cctime='bash $KIT_DIR/scripts/session-timer.sh status'
alias ccsync='bash $KIT_DIR/scripts/sync.sh'
alias ccnew='bash $KIT_DIR/scripts/create-project.sh'
ALIASES
  log "Aliases added to ~/.zshrc ✓"
else
  log "Aliases already exist ✓"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Còn 1 bước thủ công — trong Claude Code:"
echo "  /plugin marketplace add obra/superpowers-marketplace"
echo "  /plugin install superpowers@superpowers-marketplace"
echo ""
echo "Sau đó:"
echo "  source ~/.zshrc"
echo "  ccstart"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
