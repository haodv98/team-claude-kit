# Sprint-End Audit Playbook — QA Team Lead Guide

> Chạy cuối mỗi sprint, **TRƯỚC** sprint retrospective.
> Vai trò: QA Team Lead (Quality Assurance).
> Tool: `ccaudit` — xem `docs/SPRINT-AUDIT-GUIDE.md` sau khi install project scope.

---

## Trước khi bắt đầu

Checklist xác nhận sprint đã sẵn sàng audit:

- [ ] CI/CD green trên branch staging
- [ ] PR đã merge vào staging (không còn open PRs trong sprint scope)
- [ ] Test suite chạy đầy đủ: unit + integration + e2e
- [ ] `cchealth` pass trên máy QA lead
- [ ] Tất cả tasks trong sprint có status Done hoặc Review

> ⛔ **STOP**: Không audit nếu CI đang đỏ. Fix CI trước, audit sau.

---

## Phase 1: Tạo Audit Report

### Bước 1: Khởi tạo audit report

```bash
cd /path/to/project
ccaudit new
```

Wizard sẽ hỏi:
- **Sprint #**: số sprint (mặc định lấy từ `.claude/member.local.json`)
- **PR Title**: tên PR hoặc milestone ("Implement P2P Lending Flow")
- **Sprint Milestone**: tên milestone Sprint (Enter để dùng PR Title)
- **Reviewer**: tên QA reviewer (mặc định lấy từ `git config user.name`)

Report được tạo tại: `audits/sprint-N/YYYY-MM-DD-{slug}.md`

### Bước 2: Mở report

```bash
ccaudit open sprint-N
```

Hoặc mở trực tiếp trong editor:

```bash
code audits/sprint-N/*.md
```

---

## Phase 2: AI-Assisted Audit (Claude Code)

Chạy các prompts sau trong Claude Code để điền nội dung từng section. Mỗi prompt chỉ định section tương ứng trong report.

### Prompt A — Security Scan (SEC-*)

```
Act as a security auditor. Review all changed files in this sprint's PR.

Focus on OWASP Top 10:
- A01: Broken Access Control (authorization checks, user data isolation)
- A02: Cryptographic Failures (random generation, encryption, secrets)
- A03: Injection (SQL, XSS, input sanitization)
- A04: Insecure Design (race conditions, rate limiting)
- A07: Authentication Failures (JWT, session management)

For each finding:
- ID: SEC-N
- Location: file:line
- Issue: what is wrong
- Risk: High/Medium/Low
- OWASP Category: A0N:2021
- Recommendation: code snippet showing fix
- Status: MUST FIX / SHOULD FIX / ACCEPTABLE

Write findings directly into the "🔴 Critical Issues" section of audits/sprint-N/YYYY-MM-DD-*.md
```

### Prompt B — Performance Review (PERF-*)

```
Act as a performance reviewer. Analyze the sprint's changes for:
- N+1 database queries (missing includes/joins)
- Missing pagination on list endpoints
- Unbounded queries (no LIMIT)
- Missing or incorrect caching
- Blocking operations in async code
- Missing database indexes

For each finding:
- ID: PERF-N
- Location: file:line
- Issue + Problem
- Recommendation with code example
- Status: MUST FIX / SHOULD ADD / ACCEPTABLE

Write into the "🟡 Medium Issues (SHOULD FIX)" section of audits/sprint-N/YYYY-MM-DD-*.md
```

### Prompt C — Code Quality (CODE-*)

```
Act as a code reviewer. Review for:
- Functions exceeding 50 lines (split candidates)
- Deep nesting (>4 levels) — suggest early returns
- Missing input length validation (@MaxLength, etc.)
- Magic numbers without named constants
- Missing error handling (silent swallows)
- Naming convention violations

For each finding:
- ID: CODE-N
- Location: file:line
- Issue + Recommendation
- Status: MUST FIX / SHOULD FIX

Write into the "🟡 Medium Issues" section of audits/sprint-N/YYYY-MM-DD-*.md
```

### Prompt D — Điền Strengths (Tự làm)

```
Based on your review of this sprint's changes, identify 3-5 genuine strengths:
- Architecture decisions that are well-executed
- Security practices that are commendably correct
- Performance optimizations already in place
- Code quality patterns worth noting

Write into the "✅ Strengths" section of audits/sprint-N/YYYY-MM-DD-*.md
```

---

## Phase 3: Điền Scores và Verdict

### Bước 3: Tính điểm (section Metrics)

Điền 4 scores vào cuối report theo hướng dẫn:

**Code Quality Score (100 điểm khởi đầu)**
- `-5` mỗi `CODE-*` issue có status MUST FIX
- `-3` mỗi SHOULD FIX
- `-2` mỗi naming/structure issue

**Security Score (100 điểm khởi đầu)**
- `-10` mỗi `SEC-*` HIGH RISK (MUST FIX)
- `-5` mỗi MEDIUM RISK
- `-2` mỗi LOW RISK

**Performance Score (100 điểm khởi đầu)**
- `-10` mỗi missing cache (nếu đã thiết kế)
- `-5` mỗi N+1 query
- `-5` mỗi missing transaction timeout

**Compliance Score (100 điểm khởi đầu)**
- `-5` mỗi rate limiting missing
- `-3` mỗi test coverage thiếu
- `-2` mỗi coding standard violation

### Bước 4: Chọn Verdict

| Điều kiện | Verdict | Hành động |
|-----------|---------|-----------|
| Tất cả scores ≥ 80 VÀ không có Critical | ✅ **APPROVED** | Deploy staging → production |
| Có High issues, không có Critical | 🟡 **CONDITIONAL APPROVAL** | Fix list → re-review |
| Có ≥1 Critical (BLOCKING) | 🔴 **REJECTED** | Rollback / hold → escalate |

Điền verdict vào dòng `**Status:**` ở đầu report.

---

## Phase 4: Sign Off và Escalation

### Bước 5: Sign off report

Điền vào cuối report:

```markdown
**Review Completed By:** [Tên QA Lead]
**Review Date:** YYYY-MM-DD
**Next Review:** [TBD / After fixes / Sprint N+1]
```

### Bước 6: Escalation Critical Issues

⚠️ **Nếu có Critical issue (BLOCKING DEPLOY):**

1. Thông báo tech lead ngay lập tức
2. Block staging deploy — không merge vào main
3. Tạo fix tasks:

```bash
cp tasks/TASK-000-template.md tasks/phase-N/TASK-NNN-fix-sec-critical.md
ccclaim TASK-NNN
```

4. Sau khi fix: chạy lại `ccaudit new` (re-review sprint)
5. Check `🔄 Re-Review Checklist` ở cuối audit report

---

## Phase 5: Post-Audit Actions

### Bước 7: Ghi vào memory

Nếu có quyết định quan trọng từ audit (ví dụ: chọn dùng `crypto.randomUUID()` thay `Math.random()`):

```bash
# Mở memory/decisions.md và thêm entry theo format ADR
echo "### [$(date '+%Y-%m-%d')] Security: Replace Math.random() with crypto.randomUUID()
**Context:** SEC-1 finding trong Sprint N audit
**Decision:** Dùng crypto.randomUUID() cho tất cả ID generation trong financial system
**Consequences:** IDs không predictable, không collision risk
---" >> memory/decisions.md
```

### Bước 8: Thông báo team

Trong Claude Code:

```
Dùng Backlog MCP để post kết quả audit Sprint N vào channel #dev:
- Sprint: N
- Verdict: [APPROVED/CONDITIONAL/REJECTED]
- Scores: Code=NN, Security=NN, Perf=NN, Compliance=NN
- Critical issues: [danh sách hoặc "Không có"]
- Action required: [fix list hoặc "Deploy staging"]
```

### Bước 9: Xem bảng điểm tổng hợp

```bash
ccaudit summary
```

Paste bảng vào sprint retrospective notes.

---

## Approval Decision Matrix (Chi tiết)

### ✅ APPROVED — Deploy staging → production

**Điều kiện:**
- Code Quality ≥ 80
- Security ≥ 80
- Performance ≥ 80
- Compliance ≥ 80
- Không có issue nào `MUST FIX`

**Action:**
1. Điền verdict `APPROVED`
2. Notify tech lead
3. Trigger staging deploy pipeline
4. Lên lịch production deploy sau smoke test (48h)

### 🟡 CONDITIONAL APPROVAL — Fix trước khi deploy

**Điều kiện:**
- Có High issues nhưng không có Critical
- Hoặc ít nhất 1 score < 80

**Action:**
1. Điền verdict `CONDITIONAL APPROVAL`
2. List các required fixes (từ MUST FIX items)
3. Assign fix tasks với `ccclaim`
4. Set deadline: trong 2 ngày làm việc
5. Sau khi fix: `ccaudit new` → re-review
6. Dùng `🔄 Re-Review Checklist` trong report

### 🔴 REJECTED — Không deploy

**Điều kiện:**
- Có ≥1 Critical issue (BLOCKING DEPLOY)
- Security score < 70
- Confirmed race condition / data integrity risk

**Action:**
1. Điền verdict `REJECTED FOR PRODUCTION DEPLOY`
2. Notify tech lead + stakeholders ngay
3. Block merge vào main
4. Tạo fix tasks → ccclaim → fix → re-review
5. Nếu cần rollback staging: confirm với tech lead trước

---

## Scoring Guidance (Chi tiết)

### Code Quality (xuất phát 100)

| Vấn đề | Trừ điểm |
|--------|----------|
| Weak random generation (tài chính) | -5 |
| Missing XSS sanitization | -3 |
| N+1 query không fix | -2 |
| Missing input length validation | -2 |
| Magic numbers không config | -2 |
| Missing rate limiting | -3 |

### Security (xuất phát 100)

| Vấn đề | Trừ điểm |
|--------|----------|
| Cryptographic failure (SEC-1 kiểu) | -10 |
| Missing XSS protection | -5 |
| Race condition (financial) | -5 |
| Missing rate limiting | -5 |
| Error info leakage | -2 |

### Performance (xuất phát 100)

| Vấn đề | Trừ điểm |
|--------|----------|
| Missing caching (thiết kế đã có) | -10 |
| N+1 query | -5 |
| Missing transaction timeout | -5 |
| Unbounded queries | -5 |
| Missing database indexes | -3 |

### Compliance (xuất phát 100)

| Vấn đề | Trừ điểm |
|--------|----------|
| Rate limiting thiếu | -5 |
| Test coverage < 80% | -5 |
| Coding convention violations | -2 |
| Missing comments complex logic | -1 |

---

## Prompts Ready-to-Use (Claude Code)

### Prompt: Tổng quan sprint diff

```
Review tất cả files thay đổi trong sprint này.
Liệt kê: modules bị ảnh hưởng, lines changed, new dependencies.
Tóm tắt risk areas cần audit kỹ.
```

### Prompt: Kiểm tra test coverage

```
Kiểm tra test coverage cho sprint này:
1. Liệt kê files mới tạo không có test
2. Tính tỷ lệ test/implementation files
3. Kiểm tra có edge cases nào missing không
Báo cáo: coverage estimate và missing test cases.
```

### Prompt: Final verdict summary

```
Dựa trên audit report tại audits/sprint-N/YYYY-MM-DD-*.md:
Tạo executive summary ngắn gọn (< 200 từ) cho stakeholders:
- Verdict và lý do
- Top 3 strengths
- Required fixes (nếu CONDITIONAL)
- Timeline recommendation
```

---

## Audit Cadence

| Thời điểm | Action |
|-----------|--------|
| Sprint kết thúc | `ccaudit new` + điền report |
| Có Critical | Escalate ngay, block deploy |
| Sau fix | `ccaudit new` (re-review) |
| Sprint retro | `ccaudit summary` → paste bảng điểm |
| Monthly | Review trend từ `ccaudit summary` |

---

## Tham khảo

- `playbook/09-project-kickoff.md` — Setup project lần đầu
- `playbook/05-team-workflows.md` — Git + PR workflow
- `templates/audit/template.md` — Audit report template (source)
- `tasks/TASK-000-template.md` — Fix task template
- `memory/decisions.md` — Log quyết định từ audit
