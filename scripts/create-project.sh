#!/usr/bin/env bash
# scripts/create-project.sh — Khởi tạo workspace hoàn chỉnh cho project mới
# Alias: ccnew
#
# Usage:
#   ccnew                          # wizard chọn template + setup workspace
#   ccnew --name my-app            # chỉ định tên project
#   ccnew --name my-app --skip-dashboard  # bỏ qua to-do dashboard

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

# ─── Parse args ──────────────────────────────────────────────────
PROJECT_NAME=""
SKIP_DASHBOARD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)      PROJECT_NAME="$2"; shift 2 ;;
    --skip-dashboard) SKIP_DASHBOARD=true; shift ;;
    *) shift ;;
  esac
done

# ─── Chọn tên project ────────────────────────────────────────────
if [[ -z "$PROJECT_NAME" ]]; then
  printf "  ${CYAN}→${NC}  Tên project: " > /dev/tty 2>/dev/null || \
  printf "  Tên project: "
  read -r PROJECT_NAME < /dev/tty 2>/dev/null || read -r PROJECT_NAME
fi

[[ -z "$PROJECT_NAME" ]] && { err_log "Tên project không được để trống"; exit 1; }

PROJECT_DIR="$(pwd)/$PROJECT_NAME"

# ─── Chọn template ───────────────────────────────────────────────
select_template() {
  local templates=("nextjs-saas" "node-api" "internal-dashboard" "baas-service" "blank")
  _tty ""
  _tty "  Chọn template:"
  for i in "${!templates[@]}"; do
    _tty "    $((i+1)). ${templates[$i]}"
  done
  printf "  Nhập số (1-${#templates[@]}): " > /dev/tty 2>/dev/null || \
  printf "  Nhập số (1-${#templates[@]}): "
  read -r choice < /dev/tty 2>/dev/null || read -r choice
  TEMPLATE="${templates[$((choice-1))]:-blank}"
}

select_template

# ─── 1. Tạo project từ template ──────────────────────────────────
setup_project_dir() {
  info "Tạo project: $PROJECT_DIR"
  mkdir -p "$PROJECT_DIR"

  local tmpl_dir="$SCRIPT_DIR/templates/$TEMPLATE"
  if [[ -d "$tmpl_dir" ]]; then
    cp -r "$tmpl_dir/." "$PROJECT_DIR/"
    info "Template '$TEMPLATE' đã được copy"
  else
    info "Template '$TEMPLATE' chưa có — tạo blank project"
  fi
}

# ─── 2. Persistent Memory System ─────────────────────────────────
# Mỗi project có memory riêng — scope project, không dùng chung global
setup_memory() {
  info "Tạo persistent memory system..."
  local mem_dir="$PROJECT_DIR/memory"
  mkdir -p "$mem_dir"

  # decisions.md — lưu các quyết định kỹ thuật quan trọng
  cat > "$mem_dir/decisions.md" << 'EOF'
# Technical Decisions

Log các quyết định kỹ thuật quan trọng của project này.

## Format
### [YYYY-MM-DD] Tên quyết định
**Context:** Tại sao cần quyết định này?
**Decision:** Chọn gì?
**Consequences:** Ảnh hưởng gì?

---
EOF

  # people.md — stakeholders, team members liên quan
  cat > "$mem_dir/people.md" << 'EOF'
# People & Stakeholders

## Team
<!-- Thêm thành viên team và vai trò -->

## Stakeholders
<!-- Thêm stakeholders và mối quan tâm của họ -->

## Contacts
<!-- Contacts quan trọng liên quan project -->
EOF

  # preferences.md — coding conventions, tool preferences của project
  cat > "$mem_dir/preferences.md" << 'EOF'
# Project Preferences

## Coding Style
<!-- VD: tabs vs spaces, naming conventions, file structure -->

## Tools & Libraries
<!-- Các tool/lib ưu tiên dùng trong project này -->

## Workflow
<!-- Git branching, review process, deploy process -->

## Do / Don't
<!-- Những gì nên và không nên làm trong project này -->
EOF

  # user.md — context về người dùng/owner của project
  cat > "$mem_dir/user.md" << 'EOF'
# User & Project Context

## Project Goal
<!-- Mục tiêu chính của project này là gì? -->

## Target Users
<!-- Ai sẽ dùng sản phẩm này? -->

## Success Metrics
<!-- Thế nào là thành công với project này? -->

## Current Phase
<!-- Planning / Development / Testing / Production -->
EOF

  info "Memory system: $mem_dir/"
}

# ─── 3. Personality — CLAUDE.md theo project ─────────────────────
# Đọc memory + tạo personality riêng cho project này
setup_personality() {
  info "Tạo CLAUDE.md với personality cho project..."

  cat > "$PROJECT_DIR/CLAUDE.md" << EOF
# $PROJECT_NAME — Claude Workspace

## Session Start Protocol
Khi bắt đầu mỗi session, đọc các file sau theo thứ tự:
1. \`memory/user.md\` — context về project và owner
2. \`memory/decisions.md\` — các quyết định kỹ thuật đã có
3. \`memory/people.md\` — stakeholders liên quan
4. \`memory/preferences.md\` — coding style và tool preferences

Sau khi đọc, tóm tắt ngắn: "Đây là project [tên], đang ở phase [phase], ưu tiên hiện tại là [...]"

## Personality & Communication Style
- Trả lời bằng tiếng Việt trừ khi code/technical terms
- Ngắn gọn và thực tế — không giải thích dài dòng khi không cần
- Khi không chắc: hỏi thay vì đoán
- Ưu tiên giải pháp đơn giản, có thể maintain được

## Decision Making
- Tham chiếu \`memory/decisions.md\` trước khi đề xuất hướng mới
- Nếu quyết định mới mâu thuẫn với quyết định cũ, hỏi xác nhận
- Log quyết định quan trọng vào \`memory/decisions.md\`

## Session End Protocol (hook: PostToolUse)
Trước khi đóng session, cập nhật:
- \`memory/decisions.md\` nếu có quyết định mới
- \`memory/user.md\` nếu context project thay đổi
- \`memory/preferences.md\` nếu phát hiện pattern mới

## Project-Specific Rules
<!-- Thêm rules riêng cho project này -->

## Graphify
Khi cần navigate codebase lớn: \`/graphify .\`
Output tại \`graphify-out/\` — đọc \`GRAPH_REPORT.md\` để bắt đầu.
EOF

  info "CLAUDE.md đã tạo tại $PROJECT_DIR/CLAUDE.md"
}

# ─── 4. Morning Briefing System ──────────────────────────────────
setup_morning_briefing() {
  info "Tạo morning briefing system..."
  local scripts_dir="$PROJECT_DIR/.claude/scripts"
  mkdir -p "$scripts_dir"
  mkdir -p "$PROJECT_DIR/todos"

  # active.md — todos đang active
  cat > "$PROJECT_DIR/todos/active.md" << 'EOF'
# Active Tasks

<!-- Format:
- [ ] Task description [priority: high/medium/low] [agent: optional]
-->
EOF

  # Script briefing — chạy hàng ngày
  cat > "$scripts_dir/morning-briefing.sh" << 'BRIEFING'
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
BRIEFING

  chmod +x "$scripts_dir/morning-briefing.sh"

  # Hỏi có setup crontab không
  _tty ""
  _tty "  Setup crontab chạy briefing lúc 8am các ngày thường?"
  if ask "Thêm vào crontab?"; then
    local cron_entry="0 8 * * 1-5 bash $scripts_dir/morning-briefing.sh >> $PROJECT_DIR/.claude/briefing.log 2>&1"
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    info "Crontab đã được thêm: 8am Mon-Fri"
  else
    info "Bỏ qua crontab. Chạy thủ công: bash $scripts_dir/morning-briefing.sh"
  fi
}

# ─── 5. To-Do Dashboard ──────────────────────────────────────────
setup_todo_dashboard() {
  [[ "$SKIP_DASHBOARD" == true ]] && return 0

  _tty ""
  if ! ask "Tạo to-do dashboard (Next.js + Supabase)?"; then
    info "Bỏ qua dashboard"
    return 0
  fi

  info "Tạo to-do dashboard scaffold..."
  local dash_dir="$PROJECT_DIR/.claude/dashboard"
  mkdir -p "$dash_dir"

  # Supabase migration SQL
  cat > "$dash_dir/supabase-migration.sql" << 'SQL'
-- Chạy file này trong Supabase SQL Editor
-- Dashboard: https://app.supabase.com → SQL Editor

create table if not exists todos (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  status       text not null default 'todo'
                 check (status in ('todo', 'in_progress', 'done', 'blocked')),
  priority     text not null default 'medium'
                 check (priority in ('high', 'medium', 'low')),
  assigned_agent text,
  updated_at   timestamptz not null default now()
);

-- Realtime
alter publication supabase_realtime add table todos;

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger todos_updated_at
  before update on todos
  for each row execute function update_updated_at();

-- Sample data
insert into todos (title, status, priority) values
  ('Setup project structure', 'done', 'high'),
  ('Configure CI/CD', 'in_progress', 'high'),
  ('Write initial tests', 'todo', 'medium');
SQL

  # README hướng dẫn setup dashboard
  cat > "$dash_dir/README.md" << EOF
# To-Do Dashboard Setup

## 1. Supabase
1. Tạo project tại https://app.supabase.com
2. Vào SQL Editor → chạy \`supabase-migration.sql\`
3. Copy \`SUPABASE_URL\` và \`SUPABASE_ANON_KEY\` từ Settings → API

## 2. Environment
Thêm vào \`$PROJECT_DIR/.env.local\`:
\`\`\`
NEXT_PUBLIC_SUPABASE_URL=https://[project].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
\`\`\`

## 3. Tạo dashboard với Claude Code
Mở Claude Code trong project và gửi prompt sau:

\`\`\`
Build a real-time to-do dashboard using Next.js and Supabase.
The todos table already exists with fields: id, title, status, priority, assigned_agent, updated_at.
Enable Supabase Realtime so the UI updates live via websockets — no refresh needed.
When an agent completes a task, it should update the status directly in Supabase and the dashboard reflects it instantly.
Style: dark, minimal, clean.
Read memory/preferences.md for additional coding preferences.
\`\`\`

## 4. Update status từ Claude Code
\`\`\`typescript
// Agent tự update status
const { error } = await supabase
  .from('todos')
  .update({ status: 'done', assigned_agent: 'claude' })
  .eq('id', todoId)
\`\`\`
EOF

  info "Dashboard scaffold tại $dash_dir/"
  info "Đọc $dash_dir/README.md để setup tiếp"
}

# ─── 6. .gitignore cho workspace files ───────────────────────────
setup_gitignore() {
  local gi="$PROJECT_DIR/.gitignore"
  [ ! -f "$gi" ] && touch "$gi"

  local entries=(
    ".env" ".env.local" ".env.*.local"
    "graphify-out/" ".claude/briefing.log"
    "node_modules/" ".DS_Store"
  )

  for entry in "${entries[@]}"; do
    grep -qxF "$entry" "$gi" 2>/dev/null || echo "$entry" >> "$gi"
  done

  info ".gitignore đã được cập nhật"
}

# ─── Main ────────────────────────────────────────────────────────
main() {
  header "Tạo project: $PROJECT_NAME"

  run_step "Project directory"      setup_project_dir
  run_step "Persistent memory"      setup_memory
  run_step "CLAUDE.md + Personality" setup_personality
  run_step "Morning briefing"       setup_morning_briefing
  run_step "To-do dashboard"        setup_todo_dashboard
  run_step "Gitignore"              setup_gitignore

  # Graphify index nếu có code
  if command -v graphify >/dev/null 2>&1; then
    _tty ""
    if ask "Chạy graphify để index project ngay?"; then
      (cd "$PROJECT_DIR" && graphify . 2>/dev/null) || \
        warn "graphify chạy thất bại — thử lại sau: cd $PROJECT_DIR && graphify ."
    fi
  fi

  print_summary

  _tty ""
  _tty "${BOLD}  Project sẵn sàng tại:${NC} $PROJECT_DIR"
  _tty ""
  _tty "  Bước tiếp theo:"
  _tty "    cd $PROJECT_DIR"
  _tty "    ccstart"
  _tty "    # Trong Claude Code: /onboard để giới thiệu project"
  _tty ""
}

main