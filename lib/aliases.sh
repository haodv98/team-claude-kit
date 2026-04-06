#!/usr/bin/env bash
# lib/aliases.sh — Shell aliases

step_aliases() {
  local rc
  rc="$HOME/.zshrc"
  [ ! -f "$rc" ] && rc="$HOME/.bashrc"

  section "Shell aliases → $rc"

  if grep -q "# team-claude-kit" "$rc" 2>/dev/null; then
    ok "Aliases đã có trong $rc — bỏ qua"
    return 0
  fi

  if ! ask "Thêm aliases vào $rc?"; then
    info "Bỏ qua aliases"
    return 0
  fi

  local timer_script="$SCRIPT_DIR/scripts/session-timer.sh"
  local new_project="$SCRIPT_DIR/scripts/create-project.sh"

  # Tạo scripts nếu chưa có
  _create_timer_script "$timer_script"
  _create_project_script "$new_project"

  cat >> "$rc" << ALIASES

# team-claude-kit (target=${TARGET}, langs=${LANGUAGES})
alias ccstart='bash "${timer_script}" & claude'
alias cctime='bash "${timer_script}" status'
alias ccnew='bash "${new_project}"'
alias ccupdate='cd "$HOME/everything-claude-code" && git pull --quiet && bash install.sh --target ${TARGET} ${LANGUAGES} && echo "ECC updated"'
ALIASES

  ok "Aliases added → $rc"
  info "Áp dụng ngay: source $rc"
}

# ─── session-timer.sh ─────────────────────────────────────────────
_create_timer_script() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] && return 0

  cat > "$f" << 'EOF'
#!/usr/bin/env bash
DURATION=$((5*60*60))
FILE="$HOME/.claude/sessions/.timer"

_notify() {
  command -v osascript &>/dev/null \
    && osascript -e "display notification \"$1\" with title \"$2\" sound name \"${3:-Glass}\"" 2>/dev/null \
    || echo "[$2] $1"
}

case "${1:-start}" in
  status)
    [ ! -f "$FILE" ] && echo "No active session" && exit 0
    S=$(cat "$FILE"); E=$(( $(date +%s) - S )); L=$(( DURATION - E ))
    printf "Used: %dm | Left: %dm\n" $((E/60)) $((L/60)) ;;
  start|*)
    mkdir -p "$(dirname "$FILE")"
    date +%s > "$FILE"
    R=$(date -v+${DURATION}S '+%H:%M' 2>/dev/null || date -d "+${DURATION}s" '+%H:%M' 2>/dev/null || echo "in 5h")
    echo "⏱  Session started — resets at $R"
    sleep $((DURATION-600)); _notify "10min left — /wrap-session!" "Claude ⏰"
    sleep 300;               _notify "5min left!" "Claude 🔴" "Basso"
    sleep 240;               _notify "1min left!" "Claude 💀" "Sosumi"
    sleep 60;                _notify "Session reset — run ccstart" "Claude ✅" "Hero"
    rm -f "$FILE" ;;
esac
EOF
  chmod +x "$f"
}

# ─── create-project.sh ────────────────────────────────────────────
_create_project_script() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] && return 0

  cat > "$f" << 'EOF'
#!/usr/bin/env bash
set -e
KIT="$(cd "$(dirname "$0")/.." && pwd)"
echo ""; echo "New project from team-claude-kit"
echo "1) nextjs-saas  2) node-api  3) internal-dashboard  4) baas-service"
read -r -p "Template (1-4): " T
case $T in 1) TMPL="nextjs-saas";; 2) TMPL="node-api";;
           3) TMPL="internal-dashboard";; 4) TMPL="baas-service";;
           *) echo "Invalid"; exit 1;; esac
read -r -p "Project name (kebab-case): " NAME
[[ -z "$NAME" ]] && echo "Name required" && exit 1
read -r -p "Target dir [../]: " DIR; DIR="${DIR:-../}"
DEST="$DIR/$NAME"
[[ -d "$DEST" ]] && echo "Directory exists: $DEST" && exit 1

mkdir -p "$DEST/.claude/sessions"
[ -d "$KIT/templates/$TMPL" ] \
  && cp -r "$KIT/templates/$TMPL/." "$DEST/" \
  || mkdir -p "$DEST/src"
[ -f "$KIT/claude/CLAUDE.md" ] && cp "$KIT/claude/CLAUDE.md" "$DEST/CLAUDE.md"

cd "$DEST" && git init --quiet && git add . && git commit -m "chore: init from $TMPL" --quiet

command -v gitnexus &>/dev/null && gitnexus analyze --skills 2>/dev/null \
  && echo "✓ Indexed with GitNexus" || true

echo "✓ $NAME created at $DEST"
echo "  cd $DEST && pnpm install && ccstart"
EOF
  chmod +x "$f"
}