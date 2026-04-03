#!/bin/bash
# create-project.sh — Tạo project mới từ template
set -e
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$KIT_DIR/templates"
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }

echo ""; echo "Tạo project mới"; echo "================"
echo "1) nextjs-saas    — Next.js 15, Auth, Billing"
echo "2) node-api       — REST API, Prisma, Hono"
echo "3) internal-dashboard — Admin panel"
echo "4) baas-service   — Backend service"
echo ""
read -p "Template (1-4): " CHOICE
case $CHOICE in
  1) TMPL="nextjs-saas" ;;
  2) TMPL="node-api" ;;
  3) TMPL="internal-dashboard" ;;
  4) TMPL="baas-service" ;;
  *) echo "Invalid"; exit 1 ;;
esac

read -p "Tên project (kebab-case): " NAME
[[ -z "$NAME" ]] && echo "Tên không được trống" && exit 1

read -p "Thư mục đích [../]: " TARGET
TARGET="${TARGET:-../}"
DEST="$TARGET/$NAME"
[[ -d "$DEST" ]] && echo "Thư mục đã tồn tại" && exit 1

info "Tạo $NAME từ $TMPL..."
cp -r "$TEMPLATES/$TMPL" "$DEST"
find "$DEST" -type f \( -name "*.json" -o -name "*.md" -o -name "*.ts" \) \
  -exec sed -i '' "s/TEMPLATE_PROJECT_NAME/$NAME/g" {} + 2>/dev/null || \
  find "$DEST" -type f \( -name "*.json" -o -name "*.md" -o -name "*.ts" \) \
  -exec sed -i "s/TEMPLATE_PROJECT_NAME/$NAME/g" {} +

mkdir -p "$DEST/.claude/sessions"
cp "$KIT_DIR/claude/CLAUDE.md" "$DEST/CLAUDE.md"
cp "$KIT_DIR/claude/settings.json" "$DEST/.claude/settings.json"
cp -r "$KIT_DIR/claude/commands" "$DEST/.claude/"
cp -r "$KIT_DIR/claude/agents" "$DEST/.claude/"

cd "$DEST" && git init && git add . && git commit -m "chore: init from $TMPL template" --quiet
log "Project $NAME tạo xong tại $DEST"
echo ""
echo "Tiếp theo:"
echo "  cd $DEST"
echo "  cp .env.example .env.local"
echo "  pnpm install && ccstart"
