# Team Protocols — Enforced Rules

> File này được copy vào mọi project qua `lib/project.sh`. Áp dụng cho mọi task, mọi thành viên.

## Session Start (MANDATORY — làm TRƯỚC mọi thứ)

MUST đọc theo thứ tự:
1. `memory/decisions.md` — quyết định kỹ thuật đã có
2. `memory/preferences.md` — coding style của project
3. File session gần nhất trong `~/.claude/sessions/` (nếu có)

Sau khi đọc, tóm tắt ngắn: "Project [tên], phase [x], đang làm [y], context quan trọng: [z]"

## TDD (NON-NEGOTIABLE)

**Mọi feature và bug fix** phải theo đúng thứ tự này:
1. Viết test thất bại (RED) — chạy và xác nhận test FAIL
2. Implement tối thiểu để test pass (GREEN)
3. Refactor nếu cần (IMPROVE)

**NEVER** viết implementation trước test.
**NEVER** bỏ qua vì "change nhỏ" — không có change nào nhỏ đến mức không cần test.

Hook enforcement: `git commit` bị **block** nếu staged changes không có test file.
Bypass duy nhất: thêm `[skip-tests]` vào commit message (chỉ dùng cho docs/config/chore).

## Code Review (BEFORE COMMIT)

MUST chạy `/code-review` sau mọi thay đổi > 10 lines.
Không merge khi còn CRITICAL hoặc HIGH issues.

## Security Review (MANDATORY TRIGGERS)

MUST chạy `/security-scan` khi chạm vào bất kỳ điều nào sau:
- Authentication / authorization / permissions / roles
- User input handling / form data / query params
- Passwords / tokens / API keys / secrets / .env
- Payments / financial data / transactions
- Database queries với user-controlled data
- File system operations với user paths
- External API calls với credentials

Hook enforcement: Post-edit hook cảnh báo khi detect security patterns trong file vừa sửa.

## Commit Rules

Format: `type: description` (feat, fix, refactor, docs, test, chore, perf, ci)

- NEVER commit với failing tests
- NEVER dùng `git commit --no-verify` để bypass hooks
- NEVER `git push --force` vào main/master
- Staged changes MUST include test files khi có source file changes

## Session End (EVERY SESSION — không có ngoại lệ)

Trước khi đóng session, MUST làm ĐỦ 3 bước:
1. Update `memory/decisions.md` với quyết định quan trọng trong session
2. Chạy `/wrap-session`
3. Kiểm tra `git status` — không để orphaned uncommitted changes

Hook enforcement: Stop hook hiện checklist khi session kết thúc.

## Multi-Agent Delegation

Dùng `/multi-plan` + `/multi-execute` CHỈ KHI:
- 3+ subtasks độc lập có thể chạy song song
- Cần parallel FE/BE/DB work
- Pre-merge review cần nhiều góc nhìn

KHÔNG dùng cho: single-file fix, docs, config, refactor < 50 lines.

## Escalation Protocol

Khi stuck: Sonnet → Sonnet + extended thinking → Opus + think-hard → hỏi human.
KHÔNG retry cùng một approach quá 2 lần.

## NEVER LIST

- Bỏ qua TDD vì "change nhỏ"
- Bỏ qua security review vì "không có auth trong diff này"
- Quên update `memory/decisions.md` ở cuối session
- Commit mà không có tests pass
- Dùng `git commit --no-verify`
- Dùng `git push --force` vào main
- Đoán thay vì hỏi khi không chắc
