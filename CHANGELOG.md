# Changelog

## v2.0.0 — 2026-06-03

### Enforcement Layer (breaking: agent không còn tự skip quy trình)

- `claude/CLAUDE.md` — team protocols với MUST/NEVER language, được copy vào mọi project
- `claude/settings.json` — wires 3 hooks vào mọi project qua `.claude/settings.json`
- `claude/hooks/pre-commit-gate.sh` — **block** `git commit` nếu staged source files không có test files. Bypass: `[skip-tests]` trong commit message (chỉ cho docs/config/chore)
- `claude/hooks/post-edit-quality.sh` — cảnh báo khi edit file có security-sensitive patterns (auth, jwt, bcrypt, encrypt, ...)
- `claude/hooks/stop-verify.sh` — hiện checklist khi Claude session kết thúc: update memory, wrap-session, git status

### Project Skeleton (bootstrap `--project` giờ tạo đầy đủ hơn)

- `templates/` — 5 templates mới: AGENTS.md, ADR, TASK, roadmap, architecture
- `lib/project.sh` — tạo `contexts/specs/`, `contexts/adrs/`, `contexts/clarifications/`, `docs/`, `tasks/phase-1/`, `memory/`, `todos/`
- `lib/project.sh` — generate AGENTS.md từ template, copy kickoff playbook → `docs/TEAM-LEAD-SETUP.md`
- `lib/project.sh` — tạo `.claude/member.local.json` (gitignored) cho member hiện tại
- `scripts/create-project.sh` — append team protocols vào CLAUDE.md của project mới; install hooks + settings.json
- `playbook/09-project-kickoff.md` — 13-bước team lead guide với prompts ready-to-use cho specs analysis, ADRs, roadmap, task breakdown

### Member Operations (mới hoàn toàn)

- `scripts/member-init.sh` (`ccme`) — per-member local profile: name, email, phase, sprint, activeTask
- `scripts/task-status.sh` (`cctasks`) — task overview với status, claimant, conflict detection
  - `cctasks --phase 2` — xem phase cụ thể
  - `cctasks --all` — xem tất cả phases
  - `cctasks --conflicts` — Python diff map phát hiện file ownership conflicts
  - `cctasks --backlog` — live Backlog MCP status
- `ccstatus` — alias cho `cctasks --backlog`
- `ccconflicts` — alias cho `cctasks --conflicts`
- Conflict prevention 3 lớp: task-level lock (hard block), file-level overlap (warn), visibility (`cctasks --conflicts`)

### Bug Fixes

- `lib/ecc.sh` — ECC version pinning giờ thực sự checkout pinned commit (trước đây chỉ ghi file)
- `lib/project.sh` — thay gitnexus bằng graphify; thêm `_install_hooks()` copy enforcement hooks
- `scripts/claim-task.sh` — `CLAIMED_FILE` giờ dùng `$(pwd)/todos/claimed.md` của project thay vì kit directory
- `scripts/claim-task.sh` — thêm task-level conflict check: block nếu task đã được claim bởi member khác
- `scripts/claim-task.sh` — tự update `member.local.json` khi claim/unclaim
- `lib/aliases.sh` — `ccclaimed` fix dùng project claimed.md; thêm `ccme`, `cctasks`, `ccstatus`, `ccconflicts`
- `lib/project.sh` — thêm `.claude/member.local.json` vào gitignore patch

### Bootstrap Pipeline

- Thêm `step_global_hooks` sau Graphify — copy `claude/hooks/` → `~/.claude/hooks/`

---

## v1.1.0 — 2026-05 (prior)

- Chuyển từ GitNexus sang Graphify
- Thêm `lib/graphify.sh`
- `scripts/update.sh` — full update: ECC + ccg-workflow + graphify + MCP + playbook sync
- `scripts/cchealth.sh` — health check toàn bộ kit
- `scripts/claim-task.sh` — claim/unclaim files với Backlog MCP sync và stale detection
- `playbook/08-onboarding.md`
- `.ecc-version` pinning

---

## v1.0.0 — initial

- Bootstrap pipeline: ECC + ccg-workflow + MCP + aliases
- 6 MCP servers: context7, sequential-thinking, github, sentry, figma, backlog
- `scripts/create-project.sh` (`ccnew`) — memory system, CLAUDE.md, morning briefing, to-do dashboard
- `scripts/session-timer.sh` — 5h quota timer với escalating notifications
- `playbook/` 01–07: prompt patterns, context management, memory, token optimization, team workflows, agentic OS patterns, daily workflow
- `lib/secrets.sh` — 3-tier secret resolution: env → Keychain → .env.local
- `lib/backup.sh` — backup + rollback (5 generations)
