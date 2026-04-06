# team-claude-kit

Bộ cấu hình Claude Code chuẩn cho team — setup một lần, dùng mãi.

Xây dựng trên nền [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) (ECC) với bổ sung thêm [GitNexus](https://github.com/abhigyanpatwari/GitNexus) và MCP servers thiết yếu.

---

## Yêu cầu

| Tool | Version | Ghi chú |
|------|---------|---------|
| `git` | any | Bắt buộc |
| `node` / `npm` | 18+ | Bắt buộc |
| `claude` | latest | Cài bên dưới nếu chưa có |
| `docker` | any | Chỉ cần nếu dùng GitHub MCP |

---

## Cài đặt

### Bước 1 — Cài Claude Code (nếu chưa có)

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude login
```

### Bước 2 — Clone repo

```bash
git clone git@github.com:[org]/team-claude-kit.git ~/team-claude-kit
cd ~/team-claude-kit
```

### Bước 3 — Chạy bootstrap

```bash
# Mặc định: target=claude, language=typescript
bash bootstrap.sh

# Chỉ định rõ
bash bootstrap.sh --target claude --languages typescript

# Nhiều ngôn ngữ
bash bootstrap.sh --target claude --languages "typescript python"

# Cursor thay vì Claude Code
bash bootstrap.sh --target cursor --languages typescript

# Codex thay vì Claude Code
bash bootstrap.sh --target codex --languages typescript

# Không cần confirm (CI/CD hoặc onboard nhanh)
bash bootstrap.sh --yes

# Xem trước không thực thi
bash bootstrap.sh --dry-run
```

Bootstrap sẽ tự động:
- Fork và cài ECC (38 agents, 156 skills, 72 commands, hooks)
- Khởi tạo ccg-workflow runtime (cho `/multi-*` commands)
- Cài MCP servers: context7, sequential-thinking, github, sentry, figma
- Cài GitNexus và configure MCP
- Thêm aliases vào `~/.zshrc`

> Bước nào fail sẽ được log rõ — các bước còn lại vẫn tiếp tục chạy.

#### Rollback Backup Cũ

```bash
bash bootstrap.sh --target codex --rollback
```

### Bước 4 — Apply shell aliases

```bash
source ~/.zshrc
```

### Bước 5 — Cài Superpowers plugin (thủ công, trong Claude Code)

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

---

## Options

| Flag | Giá trị | Mặc định | Mô tả |
|------|---------|---------|-------|
| `--target` | `claude` \| `cursor` | `claude` | Editor target cho ECC |
| `--languages` | `typescript python golang rust php web swift` | `typescript` | Ngôn ngữ cần cài rules |
| `--yes` / `-y` | — | false | Auto-accept tất cả prompts |
| `--dry-run` | — | false | Preview, không thực thi |
| `--help` | — | — | Hiện hướng dẫn |

**Alias ngôn ngữ:** `ts` = typescript, `py` = python, `go` = golang, `rs` = rust

---

## Sử dụng hàng ngày

### Bắt đầu session

```bash
ccstart       # mở Claude Code + bật timer 5 tiếng tự động
cctime        # xem còn bao nhiêu thời gian trong session
```

### Trong Claude Code session

```
/using-superpowers      # kích hoạt Superpowers skills (bắt đầu mỗi session)
/onboard                # giới thiệu project cho người mới
/new-feature            # plan → review → implement feature mới
/code-review            # review code trước khi tạo PR
/db-migration           # tư vấn thay đổi schema an toàn
/wrap-session           # lưu context trước khi đóng
```

### Tạo project mới

```bash
ccnew         # wizard chọn template và tạo project
```

Templates có sẵn: `nextjs-saas`, `node-api`, `internal-dashboard`, `baas-service`

### Sync kit (mỗi thứ Hai)

```bash
ccupdate      # pull ECC mới nhất + reinstall rules cho target hiện tại
```

---

## API keys cho MCP

Thêm vào `~/.zshrc` trước khi chạy bootstrap (hoặc chạy lại sau khi thêm):

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."   # github.com/settings/tokens
export SENTRY_TOKEN="sntrys_..."                # sentry.io/settings/auth-tokens
export FIGMA_TOKEN="figd_..."                   # figma.com/settings → Personal tokens
```

Tạo token với scope tối thiểu:
- **GitHub**: `repo` (read), `pull_requests` (read)
- **Sentry**: `project:read`, `event:read`
- **Figma**: `File content` (read)

---

## GitNexus — Knowledge graph cho codebase

GitNexus index codebase thành knowledge graph, giúp Claude navigate mà không cần quét từng file.

### Index project mới

```bash
cd [project-dir]
gitnexus analyze --skills    # index + cài agent skills
```

### Các lệnh thường dùng

```bash
gitnexus status              # xem trạng thái index
gitnexus analyze --force     # re-index toàn bộ
gitnexus wiki                # generate docs từ graph
gitnexus list                # danh sách repos đã index
```

### Thêm vào package.json (khuyến nghị)

```json
{
  "scripts": {
    "graph": "gitnexus analyze --skills"
  }
}
```

```bash
pnpm graph    # re-index sau khi thêm nhiều file mới
```

---

## Cấu trúc repo

```
team-claude-kit/
├── bootstrap.sh          # Entry point
├── lib/
│   ├── common.sh         # Logging, helpers, step runner
│   ├── ecc.sh            # Everything Claude Code + ccg-workflow
│   ├── mcp.sh            # MCP servers
│   ├── gitnexus.sh       # GitNexus knowledge graph
│   └── aliases.sh        # Shell aliases + helper scripts
├── claude/
│   └── CLAUDE.md         # Team context override
├── scripts/
│   ├── session-timer.sh  # Timer 5 tiếng với notification
│   └── create-project.sh # Wizard tạo project mới
└── templates/
    ├── nextjs-saas/
    ├── node-api/
    ├── internal-dashboard/
    └── baas-service/
```

---

## Workflow cho team

### Git branching

```
main ← staging ← dev/[tên]/[task]
```

Mỗi người làm việc trên branch riêng. Rebase thay vì merge.

### Worktree (nhiều task song song)

```bash
git worktree add ../project-[task] dev/[tên]/[task]
cd ../project-[task] && ccstart
```

### Trước khi tạo PR

```bash
git fetch origin && git rebase origin/main
# Trong Claude Code:
/code-review
```

### Đóng góp vào kit

Khi bạn tạo ra command/agent/skill hay trong project:

1. Copy file vào `team-claude-kit/claude/[agents|skills|commands]/`
2. Test trong một project khác
3. Tạo PR vào `team-claude-kit`
4. Sau khi merge: mọi người `ccupdate` là có ngay

---

## Troubleshooting

**Bootstrap fail ở một bước nào đó**

Script tự động tiếp tục các bước còn lại. Xem log, fix issue, rồi chạy lại:

```bash
bash bootstrap.sh --target claude --languages typescript
```

Các bước đã thành công sẽ detect và skip (idempotent).

**ECC install.sh không tìm thấy**

```bash
cd ~/everything-claude-code && git pull
bash bootstrap.sh --target claude --languages typescript
```

**MCP không kết nối được**

```bash
# Kiểm tra MCP status
claude mcp list

# Xóa và cài lại
claude mcp remove context7
claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest
```

**GitNexus index quá chậm**

```bash
# Skip embeddings để nhanh hơn (mất semantic search)
gitnexus analyze --skip-embeddings
```

**`ccstart` không tìm thấy**

```bash
source ~/.zshrc
# Nếu vẫn không được:
grep "team-claude-kit" ~/.zshrc    # kiểm tra alias đã được thêm chưa
bash ~/team-claude-kit/bootstrap.sh --yes    # chạy lại
```

**Context7 báo docs không tìm thấy**

Thêm library ID trực tiếp vào prompt:

```
"Setup Prisma. use library /prisma/prisma"
"Next.js middleware. use library /vercel/next.js"
```

---

## Liên hệ & đóng góp

- Slack: `#dev-tools`
- Issues: tạo issue trong repo này
- PR: welcome — đặc biệt là agents/skills/commands mới

> Đọc thêm: [ECC Shorthand Guide](https://github.com/affaan-m/everything-claude-code/blob/main/the-shortform-guide.md) và [ECC Longform Guide](https://github.com/affaan-m/everything-claude-code/blob/main/the-longform-guide.md)