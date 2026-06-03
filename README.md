# team-claude-kit

Bộ cấu hình Claude Code chuẩn cho team — setup một lần, dùng mãi.

Xây dựng trên nền [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) (ECC). Thêm enforcement layer, project skeleton, member operations, và team lead playbook.

---

## Requirements

| Tool | Version | Ghi chú |
|------|---------|---------|
| `git` | any | Bắt buộc |
| `node` / `npm` | 18+ | Bắt buộc |
| `python3` | 3.10+ | Bắt buộc (Graphify + JSON helpers) |
| `claude` | latest | Bắt buộc — cài bên dưới nếu chưa có |
| `docker` | any | Chỉ cần nếu dùng GitHub MCP |

---

## Cài đặt

### Bước 1 — Cài Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude login
```

### Bước 2 — Clone và chạy bootstrap

```bash
git clone git@github.com:[org]/team-claude-kit.git ~/team-claude-kit
cd ~/team-claude-kit

# Mặc định: target=claude, language=typescript
bash bootstrap.sh

# Với ngôn ngữ cụ thể
bash bootstrap.sh --target claude --languages "typescript python"

# Cursor
bash bootstrap.sh --target cursor --languages typescript

# Dry-run xem trước
bash bootstrap.sh --dry-run
```

Bootstrap tự động:
1. Dependency check (fail sớm, message rõ ràng)
2. Backup config hiện tại (rollback được)
3. Clone + install ECC (agents, skills, commands, hooks)
4. Install ccg-workflow runtime (cho `/multi-*` commands)
5. Install 6 MCP servers: context7, sequential-thinking, github, sentry, figma, backlog
6. Install Graphify CLI
7. **Copy enforcement hooks** → `~/.claude/hooks/`
8. Thêm aliases vào `~/.zshrc`

### Bước 3 — Apply aliases

```bash
source ~/.zshrc
cchealth    # kiểm tra setup
```

### Bước 4 — Setup project (team lead chạy một lần cho mỗi project)

```bash
bash bootstrap.sh --project /path/to/your-project
```

Tạo đầy đủ:
- `.claude/` với agents, skills, commands, hooks, settings.json
- `contexts/specs/`, `contexts/adrs/`, `contexts/clarifications/`
- `docs/roadmap.md`, `docs/architecture.md`, `docs/TEAM-LEAD-SETUP.md`
- `tasks/phase-1/`, `tasks/TASK-000-template.md`
- `memory/`, `todos/`
- `CLAUDE.md` (project context + team protocols), `AGENTS.md`
- `.claude/member.local.json` (gitignored, per-machine)

### Bước 5 — Team members join project

Mỗi thành viên chạy bước 1-3, sau đó:

```bash
bash bootstrap.sh --project /path/to/your-project
ccme init    # setup member profile cho project này
cctasks      # xem tasks đang available
```

### Rollback

```bash
bash bootstrap.sh --rollback
```

---

## Options

| Flag | Giá trị | Mặc định | Mô tả |
|------|---------|---------|-------|
| `--target` | `claude` \| `cursor` \| `codex` | `claude` | Editor target |
| `--languages` | `typescript python golang rust php web swift` | `typescript` | Rules ngôn ngữ |
| `--project` | path | — | Cài đầy đủ skeleton vào project |
| `--yes` / `-y` | — | false | Auto-accept tất cả prompts |
| `--dry-run` | — | false | Preview, không thực thi |
| `--rollback` | — | — | Rollback backup gần nhất |

**Alias ngôn ngữ:** `ts` = typescript, `py` = python, `go` = golang, `rs` = rust

---

## Sử dụng hàng ngày

### Bắt đầu session

```bash
ccmorning    # briefing: tasks hôm nay + Backlog issues
ccme         # xem member status (phase, sprint, active task)
cctasks      # xem tasks còn lại trong phase hiện tại
ccclaim TASK-003 src/auth/   # claim task + tạo branch tự động
ccstart      # mở Claude Code + bật timer 5 tiếng
```

### Trong Claude Code

```
/tdd "feature"      → TDD workflow: RED → GREEN → REFACTOR
/code-review        → Review trước khi commit
/security-scan      → Scan trước khi merge (auth/payment/input)
/plan "feature"     → Orchestrated planning
/multi-plan "task"  → Multi-agent decomposition
/wrap-session       → Lưu context, update memory
/graphify .         → Graph codebase (navigate không cần quét files)
```

### Kết thúc ngày

```bash
ccunclaim TASK-003  # release task + clear active task
cceod               # EOD wrap: commits, Backlog update, commit suggestions
```

### Commands tham khảo

| Alias | Script | Chức năng |
|-------|--------|-----------|
| `ccstart` | session-timer.sh | Claude Code + 5h timer |
| `ccme` | member-init.sh | Member profile (phase, sprint, task) |
| `cctasks` | task-status.sh | Task overview cho current phase |
| `ccstatus` | task-status.sh --backlog | cctasks + live Backlog MCP |
| `ccconflicts` | task-status.sh --conflicts | Detect file ownership conflicts |
| `ccclaim` | claim-task.sh | Claim task + tạo branch |
| `ccunclaim` | claim-task.sh --unclaim | Release task |
| `ccclaimed` | — | Xem claimed.md của project |
| `ccnew` | create-project.sh | Tạo project mới (wizard) |
| `ccupdate` | update.sh | Update ECC + ccg-workflow + graphify + MCP |
| `cchealth` | cchealth.sh | Health check toàn bộ kit |
| `ccmorning` | claude --print | Morning briefing |
| `cceod` | claude --print | EOD wrap |
| `ccsync` | sync.sh | Sync kit từ remote |

---

## Enforcement Hooks (tự động, không cần config thêm)

Sau khi bootstrap, 3 hooks tự động active cho mọi project:

| Hook | Trigger | Effect |
|------|---------|--------|
| `pre-commit-gate` | `git commit` | **Block** nếu staged source không có test files |
| `post-edit-quality` | Write/Edit | Warn nếu file chứa auth/crypto/token patterns |
| `stop-verify` | Session end | Checklist: update memory, wrap-session, git status |

**Bypass TDD gate** (chỉ cho docs/config/chore):
```bash
git commit -m "chore: update deps [skip-tests]"
```

---

## Team Lead — Project Kickoff

Sau khi chạy `bootstrap.sh --project`:

1. Copy specs/PRDs vào `contexts/specs/`
2. Mở Claude Code: `ccstart`
3. Đọc playbook: `docs/TEAM-LEAD-SETUP.md` (13 bước)

Playbook hướng dẫn từng bước với prompts ready-to-use:
- Phân tích specs → `contexts/analysis.md`
- Confirm UNCLEAR specs → `contexts/clarifications/TBD.md`
- Tạo ADRs → `contexts/adrs/ADR-NNN-*.md`
- Tạo Roadmap → `docs/roadmap.md`
- Breakdown tasks → `tasks/phase-1/TASK-NNN-*.md`
- Update CLAUDE.md + AGENTS.md với project backbone

---

## Conflict Prevention

3 lớp bảo vệ không giẫm chân nhau:

```bash
# 1. Task-level: block nếu ai đã claim task này
ccclaim TASK-003     # → ERROR nếu TASK-003 đã claimed

# 2. File-level: warn nếu files overlap
ccclaim TASK-003 src/auth/   # → WARN nếu src/auth/ đang được dùng

# 3. Visibility: xem ai đang làm gì
cctasks              # show status + claimant mọi task
cctasks --conflicts  # Python diff map file ownership
```

---

## Graphify — Graph codebase

```bash
# Install (đã chạy tự động bởi bootstrap)
pip install graphifyy && graphify install

# Trong Claude Code
/graphify .

# Query từ terminal
graphify query "show the auth flow" --graph graphify-out/graph.json
```

---

## API Keys cho MCP

Tạo file `.env.local` trong kit directory (không commit):

```bash
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...   # github.com/settings/tokens
SENTRY_TOKEN=sntrys_...                 # sentry.io/settings/auth-tokens
FIGMA_TOKEN=figd_...                    # figma.com/settings → Personal tokens
BACKLOG_DOMAIN=yourteam.backlog.com
BACKLOG_API_KEY=...
```

Hoặc lưu vào macOS Keychain (secure hơn):

```bash
bash scripts/setup-secrets.sh
```

---

## Cấu trúc repo

```
team-claude-kit/
├── bootstrap.sh              # Entry point
├── lib/
│   ├── common.sh             # Logging, step runner, helpers
│   ├── backup.sh             # Backup + rollback (5 generations)
│   ├── secrets.sh            # 3-tier secret loading
│   ├── ecc.sh                # ECC + ccg-workflow + global hooks
│   ├── mcp.sh                # 6 MCP servers
│   ├── graphify.sh           # Graphify CLI
│   ├── aliases.sh            # Shell aliases
│   └── project.sh            # Project scope installer (full skeleton)
├── claude/                   # Team overrides → copied to every project
│   ├── CLAUDE.md             # MUST/NEVER team protocols
│   ├── settings.json         # Hook wiring
│   └── hooks/
│       ├── pre-commit-gate.sh    # TDD enforcement
│       ├── post-edit-quality.sh  # Security pattern detection
│       └── stop-verify.sh        # Session-end checklist
├── templates/                # Project templates
│   ├── AGENTS.md             # Agent roster template
│   ├── contexts/
│   │   └── ADR-000-template.md
│   ├── tasks/
│   │   └── TASK-000-template.md
│   └── docs/
│       ├── roadmap.md
│       └── architecture.md
├── scripts/
│   ├── member-init.sh        # ccme — member profile
│   ├── task-status.sh        # cctasks — task overview + conflicts
│   ├── claim-task.sh         # ccclaim / ccunclaim
│   ├── create-project.sh     # ccnew
│   ├── session-timer.sh      # ccstart timer
│   ├── update.sh             # ccupdate
│   ├── cchealth.sh           # cchealth
│   └── sync.sh               # ccsync
├── playbook/
│   ├── 01-07-*.md            # Workflow guides
│   └── 09-project-kickoff.md # Team lead setup (13 steps)
└── .ecc-version              # Pinned ECC commit hash
```

---

## Troubleshooting

**Bootstrap fail ở một bước**

Script tiếp tục, log rõ lỗi. Fix rồi chạy lại (idempotent):
```bash
bash bootstrap.sh --target claude --languages typescript
```

**ECC install.sh không tìm thấy**

```bash
cd ~/everything-claude-code && git pull
bash bootstrap.sh
```

**MCP không kết nối**

```bash
claude mcp list
claude mcp remove context7
claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest
```

**TDD gate block commit nhầm** (change không cần test)

```bash
git commit -m "chore: update config [skip-tests]"
```

**`cctasks` không hiện tasks**

```bash
ls tasks/phase-1/     # kiểm tra task files có tồn tại không
ccme init             # set phase nếu member.local.json chưa có
ccme phase 1          # hoặc set phase thủ công
```

**`ccclaim` báo conflict**

```bash
cctasks --conflicts   # xem ai đang claim gì
# Liên hệ member đó hoặc chờ họ ccunclaim
```

**`ccstart` / `ccme` không tìm thấy**

```bash
source ~/.zshrc
grep "team-claude-kit" ~/.zshrc    # verify alias đã thêm
bash bootstrap.sh --yes            # chạy lại nếu cần
```

---

## Đóng góp

1. Test thay đổi trong project khác trước
2. Tạo PR vào repo này
3. Sau khi merge: team chạy `ccupdate` là có ngay

Liên hệ: `#dev-tools` trên Slack
