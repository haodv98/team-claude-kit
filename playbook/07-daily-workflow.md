# Daily Workflow Playbook

> Mục tiêu: Mỗi member làm việc độc lập tối đa, conflict tối thiểu.
> Nguyên tắc cốt lõi: **Claim trước, code sau. Sync sớm, merge thường xuyên.**

---

## Lịch ngày chuẩn

```
08:00  Morning briefing tự động (ccmorning)
       └─ Pull issues từ Backlog API + cảnh báo conflict
08:15  Daily standup async — xem Backlog board
08:30  Bắt đầu session: ccstart → /onboard
       └─ Claude đọc memory + Backlog issues, tóm tắt context
09:00  Deep work block #1
12:00  Lunch — wrap session: /wrap-session
13:00  Deep work block #2
17:00  End of day: /wrap-session → update Backlog status
17:15  Review Backlog board cho ngày mai
```

---

## 1. Bắt đầu ngày — Morning Checklist

Trước khi viết bất kỳ dòng code nào:

```bash
# 1. Sync branch với main
git fetch origin
git rebase origin/main

# 2. Xem team đang làm gì trên Backlog (tránh đụng nhau)
ccclaimed          # ai đang claim file gì trong repo
ccmorning          # briefing đầy đủ kèm Backlog issues + deadlines

# 3. Claim task + tự động chuyển Backlog issue → In Progress
ccclaim PROJ-123 src/auth/ src/middleware/

# 4. Mở session
ccstart
```

---

## 2. Claim System — Tránh conflict chủ động

**Nguyên tắc:** Trước khi đụng vào file/module nào, claim nó trước.
Không claim = không được sửa (trừ hotfix khẩn).

### File: `todos/claimed.md`

```markdown
# Claimed Tasks

| Member | Branch | Files/Modules | Claim time | ETA |
|--------|--------|---------------|------------|-----|
| @hao   | feat/user-auth | src/auth/, src/middleware/ | 2026-04-11 09:00 | EOD |
| @nam   | feat/payment   | src/payment/, src/hooks/usePayment.ts | 2026-04-11 09:15 | Tomorrow |
```

### Claim/Unclaim nhanh trong Claude Code

```
/claim src/auth/ src/middleware/     # claim module
/unclaim src/auth/                   # release khi xong
/claimed                             # xem toàn bộ claimed list
```

### Quy tắc conflict

- **Cùng file:** Người claim sau phải hỏi người claim trước
- **Shared component** (`src/components/`, `src/hooks/`): Tạo issue + assign trước khi sửa
- **Config files** (`package.json`, `tsconfig`, `.env.example`): Báo Slack trước, merge ngay sau khi xong
- **Chưa claim mà bị conflict:** Người tạo PR sau tự resolve

---

## 3. Git Workflow hàng ngày

```
main ← staging ← dev/{name}/{task-id}-{slug}
```

### Tạo branch đúng chuẩn

```bash
# Format: dev/{tên}/{task-id}-{mô-tả-ngắn}
git checkout -b dev/hao/AUTH-123-user-login

# Hoặc dùng alias:
ccbranch AUTH-123 user-login
```

### Commit thường xuyên — ít nhất mỗi 2 tiếng

```bash
# Conventional commits
git commit -m "feat(auth): add JWT refresh token logic"
git commit -m "fix(auth): handle expired token edge case"
git commit -m "test(auth): add unit tests for token service"

# KHÔNG commit cuối ngày kiểu:
# ❌ git commit -m "wip"
# ❌ git commit -m "done"
```

### Rebase hàng ngày — KHÔNG dùng merge

```bash
# Mỗi sáng và trước khi tạo PR
git fetch origin
git rebase origin/main

# Nếu có conflict:
# 1. Báo người claim file đó trên Slack
# 2. Resolve cùng nhau — không tự resolve file của người khác
```

---

## 4. Async Standup

Không họp đồng bộ. Standup thông qua Backlog — mỗi người:

1. Cập nhật status issue trực tiếp trên Backlog board
2. Ghi comment nếu có blocker: `🚫 Blocked: chờ PROJ-456 merge`
3. Team lead xem Backlog board lúc 8:30 thay vì đọc file

Morning briefing tự động (`ccmorning`) sẽ tổng hợp lại từ API:

```
[PROJ-123] Implement JWT refresh  → @hao       | In Progress
[PROJ-124] Payment webhook        → @nam        | In Progress
[PROJ-125] UI component refactor  → @linh       | In Progress  ⚠️ shared
```

`⚠️ shared` xuất hiện khi 2+ người đang đụng cùng khu vực code.

---

## 5. Kết thúc ngày — End of Day Checklist

```bash
# Trong Claude Code:
/wrap-session          # Claude tóm tắt + update memory/

# Ngoài terminal:
git push origin dev/hao/PROJ-123-user-login

# Unclaim + tự động chuyển Backlog → Resolved
ccunclaim PROJ-123

# Nếu chưa xong hôm nay — giữ claim nhưng update ETA trên Backlog
# Vào Backlog → comment: "ETA: tomorrow EOD"
```

**Không được:** Để branch local quá 2 ngày mà không push.
**Không được:** Giữ claim + Backlog status "In Progress" qua đêm mà không comment ETA.

---

## 6. PR & Review Process

### Khi nào tạo PR
- Feature hoàn thiện, tests pass
- Hoặc sau tối đa 3 ngày làm việc (WIP PR với prefix `[WIP]`)

### Checklist trước khi tạo PR

```bash
# Trong Claude Code:
/code-review            # Claude review trước

# Sau đó:
git fetch origin && git rebase origin/main
# Tests pass
# Không có file ngoài scope claim của mình
```

### Review rules
- Mỗi PR cần ít nhất 1 reviewer
- Reviewer: ưu tiên người đang claim file liên quan
- Thời gian review: trong vòng 24h
- Không review PR của chính mình

---

## 7. Xử lý conflict khẩn

Khi phát hiện mình và người khác đang sửa cùng file:

```
1. DỪNG ngay — không commit thêm
2. Nhắn Slack: "@{member} conflict tại src/auth/token.ts — sync nhanh?"
3. Screen share 15 phút — resolve cùng nhau
4. Người tạo branch sau rebase lên branch người kia
5. Cập nhật claimed.md
```

---

## 8. Shared Components — Quy tắc đặc biệt

Các thư mục dễ conflict nhất cần quy trình riêng:

| Thư mục | Quy tắc |
|---------|---------|
| `src/components/ui/` | Chỉ team lead hoặc assigned member được sửa |
| `src/hooks/` | Tạo hook mới được, sửa hook có sẵn phải thông báo |
| `src/lib/`, `src/utils/` | Thêm file mới OK, sửa file cũ cần review |
| `package.json` | Chỉ thêm deps qua PR riêng, không gộp vào feature PR |
| `database/migrations/` | Báo cả team trước, không bao giờ revert migration |
| `CLAUDE.md`, `memory/` | Ai cũng có thể cập nhật, commit message rõ ràng |