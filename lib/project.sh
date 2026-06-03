#!/usr/bin/env bash
# lib/project.sh — Cài .claude/ scope vào một project cụ thể
#
# Layout sau khi cài:
#   <project>/
#   ├── CLAUDE.md                  ← team context (override global)
#   └── .claude/
#       ├── settings.json          ← project-level settings
#       ├── agents/                ← copy từ ECC + kit
#       ├── skills/                ← copy từ ECC + kit
#       └── commands/              ← copy từ ECC + kit
#
# Global (~/.claude/) vẫn là nền — project chỉ override những gì cần thiết.

ECC_DIR="$HOME/everything-claude-code"

step_project() {
  local proj="${PROJECT_PATH:?PROJECT_PATH is not set}"

  # ── Validate path ─────────────────────────────────────────────
  section "Validate project path"

  if [ ! -d "$proj" ]; then
    if ask "Thư mục '$proj' chưa tồn tại. Tạo mới?"; then
      run "mkdir -p '$proj'"
      ok "Created $proj"
    else
      warn "Bỏ qua project scope — thư mục không tồn tại"
      return 1
    fi
  fi

  # Resolve absolute path
  proj="$(cd "$proj" && pwd)"
  ok "Project path: $proj"

  # ── Backup .claude/ hiện tại của project ──────────────────────
  section "Backup project .claude/"

  local dot_claude="$proj/.claude"
  if [ -d "$dot_claude" ] && [ "$(ls -A "$dot_claude" 2>/dev/null)" ]; then
    local bak="$proj/.claude.bak.$(date +%Y%m%d-%H%M%S)"
    if ask "Backup .claude/ hiện tại của project?"; then
      run "cp -r '$dot_claude' '$bak'"
      ok "Backed up → $bak"
    fi
  fi

  # ── Tạo cấu trúc .claude/ ─────────────────────────────────────
  section "Tạo .claude/ structure"

  run "mkdir -p '$dot_claude'/{agents,skills,commands}"
  ok ".claude/ structure ready"

  # ── agents/ ───────────────────────────────────────────────────
  section "Install agents"
  _install_to_project "$proj" "agents" "*.md"

  # ── skills/ ───────────────────────────────────────────────────
  section "Install skills"
  _install_to_project "$proj" "skills" "*.md"

  # ── commands/ ─────────────────────────────────────────────────
  section "Install commands"
  _install_to_project "$proj" "commands" "*.md"

  # ── settings.json ─────────────────────────────────────────────
  section "Install settings.json"
  _install_settings "$proj"

  # ── CLAUDE.md ─────────────────────────────────────────────────
  section "Install CLAUDE.md"
  _install_claude_md "$proj"

  # ── .gitignore patch ──────────────────────────────────────────
  section "Patch .gitignore"
  _patch_gitignore "$proj"

  # ── Hooks ─────────────────────────────────────────────────────
  section "Install enforcement hooks"
  _install_hooks "$proj"

  # ── Project source-of-truth structure ────────────────────────
  section "Project structure (contexts/memory/docs/tasks)"
  _setup_project_structure "$proj"

  # ── AGENTS.md ─────────────────────────────────────────────────
  section "AGENTS.md"
  _generate_agents_md "$proj"

  # ── Kickoff playbook ──────────────────────────────────────────
  section "Kickoff playbook"
  _copy_kickoff_playbook "$proj"

  # ── Graphify index ────────────────────────────────────────────
  section "Graphify index"
  if command -v graphify >/dev/null 2>&1 && ask "Index project với Graphify?"; then
    info "Indexing $proj..."
    if (cd "$proj" && graphify . --no-viz 2>/dev/null); then
      ok "Graphify index done → $proj/graphify-out/"
    else
      warn "graphify failed — chạy thủ công: cd $proj && graphify ."
    fi
  fi

  _tty ""
  ok "Project scope installed → $proj"
  _tty "  ${DIM}Global (~/.claude/) vẫn là nền — project override lên trên${NC}"
  _print_next_steps "$proj"
}

# ─── Helpers ─────────────────────────────────────────────────────

# Copy files từ kit và ECC vào .claude/<subdir>/ của project
# Thứ tự ưu tiên: ECC → kit (kit cuối cùng = override cao nhất)
_install_to_project() {
  local proj="$1" subdir="$2" pattern="$3"
  local dest="$proj/.claude/$subdir"
  local copied=0

  # 1. Từ ECC
  local ecc_src="$ECC_DIR/$subdir"
  if [ -d "$ecc_src" ]; then
    for f in "$ecc_src"/$pattern; do
      [ -e "$f" ] || continue
      local name; name="$(basename "$f")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy ECC/$subdir/$name → .claude/$subdir/"
      else
        cp "$f" "$dest/$name" 2>/dev/null && ((copied++)) || true
      fi
    done
    # ECC có thể dùng subdirectory cho skills
    for d in "$ecc_src"/*/; do
      [ -d "$d" ] || continue
      local dname; dname="$(basename "$d")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy ECC/$subdir/$dname/ → .claude/$subdir/"
      else
        cp -r "$d" "$dest/$dname" 2>/dev/null && ((copied++)) || true
      fi
    done
  fi

  # 2. Từ kit (override ECC nếu cùng tên)
  local kit_src="$SCRIPT_DIR/claude/$subdir"
  if [ -d "$kit_src" ]; then
    for f in "$kit_src"/$pattern; do
      [ -e "$f" ] || continue
      local name; name="$(basename "$f")"
      if [ "${DRY_RUN:-false}" = true ]; then
        info "[dry-run] copy kit/$subdir/$name → .claude/$subdir/"
      else
        cp "$f" "$dest/$name" 2>/dev/null && ((copied++)) || true
      fi
    done
  fi

  if [ $copied -gt 0 ]; then
    ok "$copied $subdir installed → .claude/$subdir/"
  else
    info "Không có $subdir files — bỏ qua"
  fi
}

# settings.json cho project — nhẹ hơn global, chỉ override cần thiết
_install_settings() {
  local proj="$1"
  local dest="$proj/.claude/settings.json"

  # Nếu đã có, hỏi trước khi ghi đè
  if [ -f "$dest" ]; then
    if ! ask "settings.json đã tồn tại trong project. Ghi đè?"; then
      info "Giữ nguyên settings.json hiện tại"
      return 0
    fi
  fi

  # Dùng settings.json của kit nếu có, không thì tạo minimal
  local kit_settings="$SCRIPT_DIR/claude/settings.json"
  if [ -f "$kit_settings" ]; then
    run "cp '$kit_settings' '$dest'"
    ok "settings.json copied from kit"
  else
    [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $dest"; return 0; }
    cat > "$dest" << 'JSON'
{
  "model": "claude-sonnet-4-6",
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
JSON
    ok "settings.json created (minimal)"
  fi
}

# CLAUDE.md — copy từ kit, thêm project-specific header
_install_claude_md() {
  local proj="$1"
  local dest="$proj/CLAUDE.md"
  local kit_md="$SCRIPT_DIR/claude/CLAUDE.md"

  if [ -f "$dest" ]; then
    if ! ask "CLAUDE.md đã tồn tại. Ghi đè?"; then
      info "Giữ nguyên CLAUDE.md hiện tại"
      return 0
    fi
  fi

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] write $dest"; return 0; }

  local proj_name; proj_name="$(basename "$proj")"

  # Header project-specific + nội dung từ kit
  {
    cat << MD
# $proj_name — Claude Context

> Project-level override. Global context tại ~/.claude/CLAUDE.md vẫn áp dụng.
> Sửa file này để customize riêng cho project này.

MD
    # Append team CLAUDE.md nếu có
    [ -f "$kit_md" ] && cat "$kit_md"
  } > "$dest"

  ok "CLAUDE.md created → $dest"
}

# ─── Source-of-truth project structure ──────────────────────────
_setup_project_structure() {
  local proj="$1"
  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] create project structure"; return 0; }

  local tmpl="$SCRIPT_DIR/templates"

  # contexts/ — specs, ADRs, clarifications
  mkdir -p "$proj/contexts/specs" "$proj/contexts/adrs" "$proj/contexts/clarifications"
  touch "$proj/contexts/specs/.gitkeep"

  # ADR template
  [ -f "$tmpl/contexts/ADR-000-template.md" ] && \
    cp "$tmpl/contexts/ADR-000-template.md" "$proj/contexts/adrs/"

  # Deferred clarifications placeholder
  [ -f "$proj/contexts/clarifications/TBD.md" ] || cat > "$proj/contexts/clarifications/TBD.md" << 'EOF'
# Deferred Clarifications (TBD)

Spec items that need stakeholder confirmation but are deferred.
Resolve each before the relevant phase/sprint begins.

| ID | Item | Owner | Due | Status |
|----|------|-------|-----|--------|
| TBD-001 | [Unclear spec item] | @TBD | Phase 1 | Open |
EOF

  # docs/ — architecture, roadmap
  mkdir -p "$proj/docs"
  [ -f "$tmpl/docs/roadmap.md" ]      && { [ -f "$proj/docs/roadmap.md" ]      || cp "$tmpl/docs/roadmap.md"      "$proj/docs/roadmap.md"; }
  [ -f "$tmpl/docs/architecture.md" ] && { [ -f "$proj/docs/architecture.md" ] || cp "$tmpl/docs/architecture.md" "$proj/docs/architecture.md"; }

  # tasks/ — phase-1 + template
  mkdir -p "$proj/tasks/phase-1"
  touch "$proj/tasks/phase-1/.gitkeep"
  [ -f "$tmpl/tasks/TASK-000-template.md" ] && \
    { [ -f "$proj/tasks/TASK-000-template.md" ] || cp "$tmpl/tasks/TASK-000-template.md" "$proj/tasks/"; }

  # memory/ — persistent AI memory (skip if already created by ccnew)
  mkdir -p "$proj/memory"
  if [ ! -f "$proj/memory/decisions.md" ]; then
    cat > "$proj/memory/decisions.md" << 'EOF'
# Technical Decisions

Format:
### [YYYY-MM-DD] Decision title
**Context:** Why needed? **Decision:** What chosen? **Consequences:** Impacts?
---
EOF
    cat > "$proj/memory/people.md"      << 'EOF'
# People & Stakeholders
## Team <!-- Name | Role | Area -->
## Stakeholders <!-- Name | Contact | Concern -->
EOF
    cat > "$proj/memory/preferences.md" << 'EOF'
# Project Preferences
## Coding Style <!-- conventions, naming, file structure -->
## Tools & Libraries <!-- preferred choices for this project -->
## Do / Don't <!-- project-specific dos and don'ts -->
EOF
    cat > "$proj/memory/user.md"        << 'EOF'
# Project Context
## Goal <!-- one-sentence goal -->
## Target Users <!-- who uses this? -->
## Current Phase <!-- Planning / Development / Testing / Production -->
## Success Metrics <!-- what does success look like? -->
EOF
  fi

  # todos/ — active tasks + claim file
  mkdir -p "$proj/todos"
  [ -f "$proj/todos/active.md" ] || cat > "$proj/todos/active.md" << 'EOF'
# Active Tasks
<!-- - [ ] Task [priority: high/medium/low] [agent: optional] -->
EOF

  # audits/ — sprint-end QA audit reports
  _setup_audit_structure "$proj"

  # deploys/ — staging + production deploy gate records
  _setup_deploy_structure "$proj"

  # Initialize member.local.json for current developer (gitignored)
  local member_file="$proj/.claude/member.local.json"
  if [ ! -f "$member_file" ]; then
    local git_name git_email
    git_name="$(git config user.name 2>/dev/null || echo "")"
    git_email="$(git config user.email 2>/dev/null || echo "")"
    python3 -c "
import json, datetime
d = {
  'name': '''$git_name''',
  'email': '''$git_email''',
  'phase': 1,
  'sprint': 1,
  'activeTask': None,
  'updatedAt': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
}
json.dump(d, open('$member_file', 'w'), indent=2)
" 2>/dev/null && ok "member.local.json created (gitignored)" || true
  fi

  ok "Project structure created: contexts/ docs/ tasks/ memory/ todos/ audits/ deploys/"
}

# ─── Generate AGENTS.md from template ───────────────────────────
_generate_agents_md() {
  local proj="$1"
  local dest="$proj/AGENTS.md"
  local tmpl="$SCRIPT_DIR/templates/AGENTS.md"
  local proj_name; proj_name="$(basename "$proj")"

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] generate AGENTS.md"; return 0; }

  # Skip if already has a real AGENTS.md (not a stub)
  if [ -f "$dest" ] && [ "$(wc -l < "$dest")" -gt 10 ]; then
    info "AGENTS.md already exists ($(wc -l < "$dest") lines) — skipping"
    return 0
  fi

  if [ -f "$tmpl" ]; then
    sed "s/{{PROJECT_NAME}}/$proj_name/g; s/{{STACK}}/TBD/g; s/{{DATABASE}}/TBD/g; s/{{TESTING}}/TBD/g" \
      "$tmpl" > "$dest"
    ok "AGENTS.md generated → AGENTS.md"
  else
    info "No AGENTS.md template found — skipping"
  fi
}

# ─── Sprint audit structure: audits/ + QA guide ─────────────────
_setup_audit_structure() {
  local proj="$1"
  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] setup audit structure"; return 0; }

  mkdir -p "$proj/audits/sprint-1"
  touch "$proj/audits/sprint-1/.gitkeep"

  local src="$SCRIPT_DIR/playbook/10-sprint-audit-playbook.md"
  local dest="$proj/docs/SPRINT-AUDIT-GUIDE.md"
  if [ -f "$src" ]; then
    [ -f "$dest" ] || cp "$src" "$dest"
    ok "Sprint audit guide → docs/SPRINT-AUDIT-GUIDE.md"
  else
    info "Sprint audit playbook not found — skipping"
  fi

  ok "Audit structure created: audits/sprint-1/"
}

# ─── Deploy gate structure: deploys/ + deploy guide ──────────────
_setup_deploy_structure() {
  local proj="$1"
  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] setup deploy structure"; return 0; }

  mkdir -p "$proj/deploys/staging" "$proj/deploys/production"
  touch "$proj/deploys/staging/.gitkeep"
  touch "$proj/deploys/production/.gitkeep"

  local src="$SCRIPT_DIR/playbook/11-deploy-playbook.md"
  local dest="$proj/docs/DEPLOY-GUIDE.md"
  if [ -f "$src" ]; then
    [ -f "$dest" ] || cp "$src" "$dest"
    ok "Deploy guide → docs/DEPLOY-GUIDE.md"
  else
    info "Deploy playbook not found — skipping"
  fi

  ok "Deploy structure created: deploys/staging/ deploys/production/"
}

# ─── Copy kickoff playbook into project ─────────────────────────
_copy_kickoff_playbook() {
  local proj="$1"
  local src="$SCRIPT_DIR/playbook/09-project-kickoff.md"
  local dest="$proj/docs/TEAM-LEAD-SETUP.md"

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] copy kickoff playbook"; return 0; }

  if [ -f "$src" ]; then
    cp "$src" "$dest"
    ok "Team lead playbook → docs/TEAM-LEAD-SETUP.md"
  else
    info "Kickoff playbook not found — skipping"
  fi
}

# ─── Print next steps for team lead ─────────────────────────────
_print_next_steps() {
  local proj="$1"
  local proj_name; proj_name="$(basename "$proj")"

  _tty ""
  _tty "  ┌─────────────────────────────────────────────────────────┐"
  _tty "  │  NEXT STEPS — Team Lead                                 │"
  _tty "  └─────────────────────────────────────────────────────────┘"
  _tty ""
  _tty "  1. Add specs/PRDs:    cp /path/to/spec.md $proj/contexts/specs/"
  _tty "  2. Open Claude Code:  cd $proj && ccstart"
  _tty "  3. Follow playbook:   docs/TEAM-LEAD-SETUP.md"
  _tty ""
  _tty "  Project structure:"
  _tty "    contexts/specs/     ← Add PRDs/requirements here"
  _tty "    contexts/adrs/      ← Architecture decisions (Step 5)"
  _tty "    docs/roadmap.md     ← Roadmap (Step 7)"
  _tty "    tasks/phase-1/      ← Task breakdown (Step 8)"
  _tty "    CLAUDE.md           ← Update with project context (Step 9)"
  _tty "    AGENTS.md           ← Update team assignments (Step 10)"
  _tty "    audits/sprint-1/    ← Sprint-end QA audits (ccaudit new)"
  _tty "    deploys/staging/    ← Staging deploy gates (ccdeploy new staging)"
  _tty "    deploys/production/ ← Production deploy gates (ccdeploy new production)"
  _tty ""
  _tty "  Playbooks:"
  _tty "    docs/TEAM-LEAD-SETUP.md     ← Project kickoff"
  _tty "    docs/SPRINT-AUDIT-GUIDE.md  ← Sprint-end QA audit"
  _tty "    docs/DEPLOY-GUIDE.md        ← Staging & production deploy"
  _tty ""
}

# Copy enforcement hooks từ claude/hooks/ vào project .claude/hooks/
_install_hooks() {
  local proj="$1"
  local src="$SCRIPT_DIR/claude/hooks"
  local dest="$proj/.claude/hooks"

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] install hooks → .claude/hooks/"; return 0; }

  if [ ! -d "$src" ]; then
    info "No hooks directory in kit (claude/hooks/) — skipping"
    return 0
  fi

  mkdir -p "$dest"
  local count=0
  for f in "$src"/*.sh; do
    [ -e "$f" ] || continue
    cp "$f" "$dest/"
    chmod +x "$dest/$(basename "$f")"
    ((count++))
  done

  [ $count -gt 0 ] \
    && ok "$count hook(s) installed → .claude/hooks/" \
    || info "No .sh files in claude/hooks/"
}

# Thêm .claude/sessions/ vào .gitignore (sessions không nên commit)
_patch_gitignore() {
  local proj="$1"
  local gi="$proj/.gitignore"

  [ "${DRY_RUN:-false}" = true ] && { info "[dry-run] patch $gi"; return 0; }

  local entries=(
    ".claude/sessions/"
    ".claude/audit.log"
    ".claude/member.local.json"
    ".gitnexus/"
  )

  local added=0
  for entry in "${entries[@]}"; do
    if ! grep -qxF "$entry" "$gi" 2>/dev/null; then
      echo "$entry" >> "$gi"
      ((added++))
    fi
  done

  [ $added -gt 0 ] \
    && ok "Added $added entries to .gitignore" \
    || info ".gitignore đã có các entries cần thiết"
}