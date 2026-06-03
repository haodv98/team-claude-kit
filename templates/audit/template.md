<!-- AUDIT VARS (auto-filled by `ccaudit new`):
     {{PROJECT_NAME}} {{SPRINT_NUMBER}} {{SPRINT_MILESTONE}} {{PR_TITLE}} {{REVIEWER}} {{DATE}} -->

# PR Review Report

## {{PROJECT_NAME}} — {{SPRINT_MILESTONE}}

**Reviewer:** {{REVIEWER}}
**Date:** {{DATE}}
**Sprint:** {{SPRINT_NUMBER}}
**PR Title:** {{PR_TITLE}}
**Status:** ⬜ **PENDING** (Đang review)

---

## 📋 Executive Summary

PR này implement:

- ✅ [Feature/module chính 1]
- ✅ [Feature/module chính 2]
- ✅ [Feature/module chính 3]

**Overall Assessment:** [Nhận xét tổng quan — code quality, compliance, risks nổi bật]

---

## ✅ Strengths

### 1. Code Quality

- ✅ [Điểm mạnh về naming conventions, readability]
- ✅ [Điểm mạnh về error handling]
- ✅ [Điểm mạnh về input validation]
- ✅ [Điểm mạnh khác]

### 2. Architecture Compliance

- ✅ [Tuân thủ module structure]
- ✅ [Dependency Injection / DI pattern]
- ✅ [Separation of concerns]
- ✅ [Config management]

### 3. Security — Good Practices

- ✅ [Không có hard-coded secrets]
- ✅ [Không log sensitive data]
- ✅ [Input validation implemented]
- ✅ [Parameterized queries / ORM]

### 4. Performance

- ✅ [Database transactions / atomic ops]
- ✅ [Pagination implemented]
- ✅ [Proper field selection (select/projection)]
- ⬜ [Caching — nếu chưa có ghi rõ]

---

## 🔴 Critical Issues (BLOCKING DEPLOY)

> Điền mỗi finding theo format bên dưới. Xóa section này nếu không có Critical issues.

### SEC-1: [Tên issue] ⚠️ HIGH RISK

**Location:**

- `[service/file]:line`

**Issue:**

```
[Code snippet minh họa vấn đề]
```

**Problem:**

- [Mô tả vấn đề cụ thể]
- [Tác động / attack vector]

**OWASP Category:** [A0N:2021 – Category Name]

**Risk:** High / Medium-High

**Recommendation:**

```
[Code snippet fix]
```

**Status:** 🔴 **MUST FIX BEFORE DEPLOY**

---

<!-- Thêm SEC-2, SEC-3, ... nếu cần -->

---

## 🟡 Medium Issues (SHOULD FIX)

> Điền findings không blocking nhưng cần address trước hoặc sau deploy.

### PERF-1: [Tên performance issue]

**Location:**

- `[file]:line`

**Issue:**

- [Mô tả vấn đề]

**Recommendation:**

```
[Fix suggestion]
```

**Status:** 🟡 **SHOULD FIX**

---

### CODE-1: [Tên code quality issue]

**Location:**

- `[file]:line`

**Issue:**

```
[Code snippet]
```

**Problem:**

- [Mô tả vấn đề]

**Recommendation:**

```
[Fix suggestion]
```

**Status:** 🟡 **SHOULD FIX**

---

<!-- Thêm PERF-N, CODE-N, ... nếu cần -->

---

## ✅ Code Standards Compliance

### File Naming

- ✅/❌ Controllers: `*.controller.[ext]`
- ✅/❌ Services: `*.service.[ext]`
- ✅/❌ Modules/Routers: `*.module.[ext]`
- ✅/❌ DTOs/Schemas: `*.dto.[ext]` / `*.schema.[ext]`

### Naming Conventions

- ✅/❌ Variables: camelCase
- ✅/❌ Classes/Types: PascalCase
- ✅/❌ Constants: UPPER_SNAKE_CASE
- ✅/❌ Database: snake_case

### Code Organization

- ✅/❌ Single responsibility per file
- ✅/❌ Proper module/package structure
- ✅/❌ Dependency Injection pattern
- ✅/❌ No circular dependencies

### Error Handling

- ✅/❌ Custom exceptions / typed errors
- ✅/❌ User-friendly error messages
- ✅/❌ Proper logging với context
- ✅/❌ No sensitive data in logs

### Input Validation

- ✅/❌ Schema-based validation (class-validator / zod / joi)
- ✅/❌ Enum validation
- ✅/❌ Number validation với min/max
- ✅/❌ String length validation (@MaxLength)

### Database

- ✅/❌ Transactions cho multi-step operations
- ✅/❌ Soft delete pattern
- ✅/❌ Proper field selection (avoid SELECT *)
- ✅/❌ Pagination on list queries

---

## 🔒 Security Review (OWASP Top 10)

### A01:2021 – Broken Access Control

- ✅/❌ Authorization checks implemented
- ✅/❌ User can only access own data
- ✅/❌ Role-based access enforced
- ⚠️ **ISSUE:** [nếu có — ghi ref SEC-N]

### A02:2021 – Cryptographic Failures

- ✅/❌ Sensitive data encrypted at rest
- ✅/❌ No hard-coded secrets
- ✅/❌ Cryptographically secure random generation
- ⚠️ **ISSUE:** [nếu có]

### A03:2021 – Injection

- ✅/❌ ORM / parameterized queries (no raw SQL concat)
- ✅/❌ Input validation với schema validator
- ✅/❌ XSS sanitization cho user-generated content
- ⚠️ **ISSUE:** [nếu có]

### A04:2021 – Insecure Design

- ✅/❌ Race condition prevention (validation inside transaction)
- ✅/❌ Rate limiting implemented
- ✅/❌ Business logic constraints enforced
- ⚠️ **ISSUE:** [nếu có]

### A05:2021 – Security Misconfiguration

- ✅/❌ Config management centralized
- ✅/❌ Environment variables used (no hardcoded config)
- ✅/❌ No default credentials
- ⚠️ **ISSUE:** [nếu có]

### A06:2021 – Vulnerable Components

- ✅/❌ Dependencies up-to-date (verify: `npm audit` / `pip audit`)
- ✅/❌ No known CVEs in direct deps
- ⚠️ **ISSUE:** [nếu có]

### A07:2021 – Authentication Failures

- ✅/❌ JWT / session validation implemented
- ✅/❌ Auth middleware / guards on protected endpoints
- ✅/❌ Token expiry handled correctly
- ⚠️ **ISSUE:** [nếu có]

### A08:2021 – Software and Data Integrity

- ✅/❌ Input validation at all entry points
- ✅/❌ Transaction integrity (atomic operations)
- ✅/❌ Audit log / soft delete for data integrity
- ⚠️ **ISSUE:** [nếu có]

### A09:2021 – Logging Failures

- ✅/❌ Structured logging với context (Logger, not console.log)
- ✅/❌ Error logging với stack trace (server-side only)
- ✅/❌ No sensitive data in logs (PII, tokens, passwords)
- ⚠️ **ISSUE:** [nếu có]

### A10:2021 – SSRF

- ✅/❌ No unvalidated external URL fetching
- ✅/❌ Allowlist for external domains (nếu có)
- ⚠️ **ISSUE:** [nếu có]

---

## ⚡ Performance Review

### Database Queries

- ✅/❌ Transactions used cho multi-step writes
- ✅/❌ Pagination trên tất cả list endpoints
- ✅/❌ Field projection (select chỉ fields cần thiết)
- ✅/❌ Indexes tồn tại cho query patterns chính

### Caching

- ✅/❌ Caching layer implemented (Redis / in-memory)
- ✅/❌ Cache TTL configured hợp lý
- ✅/❌ Cache invalidation khi data thay đổi
- ⚠️ **ISSUE:** [nếu có]

### Response Times

- ✅/❌ Queries optimized (no N+1)
- ✅/❌ No blocking operations trong async handlers
- ✅/❌ Transaction timeout configured
- ✅/❌ Async/await dùng đúng (no fire-and-forget)

### Memory Usage

- ✅/❌ No unbounded in-memory collections
- ✅/❌ Streams dùng cho large data (nếu áp dụng)
- ⚠️ **ISSUE:** [nếu có]

---

## 📊 Test Coverage

### Unit Tests

- ✅/❌ Service layer covered
- ✅/❌ Edge cases tested
- ✅/❌ Error paths tested
- Coverage: **[N]%** (target: ≥80%)

### Integration Tests

- ✅/❌ API endpoints tested
- ✅/❌ Database operations tested
- ✅/❌ Auth flows tested

### E2E Tests

- ✅/❌ Critical user flows covered
- ✅/❌ Happy path + error path

**Overall Coverage:** [N]% — ✅ meets 80% threshold / ❌ below threshold

---

## 📝 Specific Code Review Findings

### ✅ Good Practices Found

1. **[Pattern tốt 1]:**
   ```
   [Code snippet minh họa]
   ```
   ✅ [Giải thích tại sao đây là good practice]

2. **[Pattern tốt 2]:**
   ```
   [Code snippet]
   ```
   ✅ [Giải thích]

3. **[Pattern tốt 3]:**
   ✅ [Giải thích]

### 🔴 Issues Found (Summary)

1. **[Issue ID từ section Critical/Medium] — [Tên ngắn]:**
   ```
   // ❌ BAD
   [code hiện tại]

   // ✅ GOOD
   [code fix]
   ```

2. **[Issue ID] — [Tên ngắn]:**
   ```
   // ❌ BAD
   [code]

   // ✅ GOOD
   [fix]
   ```

---

## 📋 Checklist

### Security

- [ ] No hard-coded secrets
- [ ] Input validation implemented
- [ ] SQL/NoSQL injection prevented (ORM / parameterized)
- [ ] Authentication/Authorization enforced
- [ ] No sensitive data logged
- [ ] **Rate limiting** ✅/❌
- [ ] **XSS sanitization** ✅/❌
- [ ] **Cryptographically secure random** ✅/❌

### Performance

- [ ] Database transactions where needed
- [ ] Caching implemented ✅/❌
- [ ] Pagination on all list endpoints
- [ ] Indexes verified
- [ ] **N+1 queries eliminated** ✅/❌
- [ ] **Transaction timeout configured** ✅/❌

### Code Quality

- [ ] Naming conventions followed
- [ ] File structure correct
- [ ] Error handling comprehensive
- [ ] TypeScript strict / type safety enforced
- [ ] Comments for complex business logic
- [ ] **Input length validation** ✅/❌
- [ ] **No magic numbers** ✅/❌

### Testing

- [ ] Unit tests written (≥80% coverage)
- [ ] Integration tests written
- [ ] Edge cases covered
- [ ] **All tests passing** ✅/❌

---

## 🎯 Final Verdict

### Overall Assessment: ⬜ **[APPROVED / CONDITIONAL APPROVAL / REJECTED]**

**Status:** ⬜ **[READY / NOT READY] FOR PRODUCTION DEPLOY**

### Required Fixes Before Deploy:

1. **🔴 CRITICAL:** [Issue ref — SEC-N]
   - [Action required]
   - **Impact:** High / Medium / Low
   - **Effort:** [estimate]

2. **🟡 HIGH PRIORITY:** [Issue ref]
   - [Action required]
   - **Impact:** [level]
   - **Effort:** [estimate]

<!-- Thêm items nếu cần -->

### Recommended Fixes (Can Deploy After):

3. **🟢 LOW PRIORITY:** [Issue ref]
   - [Action]
   - **Impact:** Low
   - **Effort:** [estimate]

---

## 📝 Approval Decision

### ⬜ **[APPROVED / REJECTED] FOR PRODUCTION DEPLOY**

**Reason:** [Lý do chính — critical issues hoặc all clear]

### ⬜ **[APPROVED / PENDING] FOR STAGING DEPLOY**

[Điều kiện nếu có]

### 📋 Next Steps:

1. **Developer Actions:**
   - [ ] [Fix action 1 — ref SEC-N / CODE-N / PERF-N]
   - [ ] [Fix action 2]
   - [ ] [Fix action 3]

2. **QA Actions:**
   - [ ] Re-review sau khi fixes
   - [ ] Run security scan (`npm audit` / `pip audit` / `trivy`)
   - [ ] Performance testing
   - [ ] Smoke test trên staging

3. **After Fixes:**
   - [ ] Re-run unit tests
   - [ ] Re-run integration tests
   - [ ] Manual testing critical flows
   - [ ] Update CHANGELOG / release notes

---

## 📊 Metrics

### Code Quality Score: **[N]/100**

- **Deductions:**
  - -[N]: [Reason — CODE-N]
  - -[N]: [Reason]

### Security Score: **[N]/100**

- **Deductions:**
  - -[N]: [Reason — SEC-N]
  - -[N]: [Reason]

### Performance Score: **[N]/100**

- **Deductions:**
  - -[N]: [Reason — PERF-N]
  - -[N]: [Reason]

### Compliance Score: **[N]/100**

- **Deductions:**
  - -[N]: [Reason]
  - -[N]: [Reason]

---

## ✅ Positive Highlights

1. **[Highlight 1]:** [Mô tả]
2. **[Highlight 2]:** [Mô tả]
3. **[Highlight 3]:** [Mô tả]

---

**Review Completed By:** {{REVIEWER}}
**Review Date:** {{DATE}}
**Next Review:** [TBD / After fixes / Sprint {{SPRINT_NUMBER}} + 1]

---

## 🔄 Re-Review Checklist

Sau khi developer fix các issues, QA sẽ re-review:

- [ ] [SEC-1 fix verified]
- [ ] [SEC-2 fix verified]
- [ ] [PERF-1 fix verified]
- [ ] [CODE-1 fix verified]
- [ ] All tests passing
- [ ] Security scan clean (`npm audit` / equivalent)
- [ ] Performance acceptable (no regression)
- [ ] Staging smoke test passed

**Expected Re-Review Date:** TBD
**Expected Approval:** ✅ After fixes verified
