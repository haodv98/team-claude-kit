<!-- DEPLOY VARS (auto-filled by `ccdeploy new staging`):
     {{PROJECT_NAME}} {{VERSION}} {{SPRINT_NUMBER}} {{DEPLOYER}} {{DATE}} {{AUDIT_FILE}} -->

# Staging Deploy Gate

## {{PROJECT_NAME}} — v{{VERSION}} → Staging

**Deployer:** {{DEPLOYER}}
**Date:** {{DATE}}
**Sprint:** {{SPRINT_NUMBER}}
**Audit Ref:** {{AUDIT_FILE}}
**Status:** ⬜ **PENDING**

---

## 📋 Pre-Deploy Checklist

> Tick từng mục trước khi deploy. ⛔ STOP nếu bất kỳ mục nào fail.

### CI/CD

- [ ] CI pipeline green trên branch được deploy
- [ ] Tất cả checks pass (lint, typecheck, test)
- [ ] Không có open PRs chưa merge trong sprint scope

### Quality Gate

- [ ] Sprint audit đã complete: `{{AUDIT_FILE}}`
- [ ] Audit verdict: CONDITIONAL APPROVAL hoặc APPROVED (không phải REJECTED)
- [ ] Tất cả MUST FIX items từ audit đã được fix và verified

### Database

- [ ] DB migrations reviewed (không có destructive ops: DROP, truncate without backup)
- [ ] Migration rollback script tồn tại (nếu schema thay đổi)
- [ ] Seeds/fixtures không ghi đè production data

### Configuration

- [ ] Environment variables đã set trên staging server
- [ ] Feature flags configured đúng cho staging
- [ ] Third-party API keys là staging/sandbox keys (không dùng prod keys)
- [ ] Secrets không commit vào code

### Dependencies

- [ ] `npm audit` / `pip audit` / equivalent pass (không có CRITICAL CVEs)
- [ ] New dependencies đã được review

### Rollback Plan

- [ ] Previous version tag/image đã xác định: `v[PREV_VERSION]`
- [ ] Rollback command sẵn sàng: `[rollback command]`
- [ ] DB rollback script sẵn sàng (nếu có migration)
- [ ] Estimated rollback time: `[N] minutes`

---

## 🚀 Deploy Execution

**Target:** Staging environment
**Deploy method:** `[docker/k8s/PM2/Vercel/manual — điền vào]`
**Deploy command:**

```bash
# Điền deploy command thực tế ở đây
```

**Started at:** [HH:MM]
**Completed at:** [HH:MM]
**Duration:** [N minutes]

### Migrations

- [ ] Migrations chạy thành công
- [ ] Migration output: [OK / WARN / N/A]

---

## ✅ Post-Deploy Smoke Test

> Chạy sau khi deploy xong. Tất cả phải pass trước khi declare DEPLOYED.

### Health Checks

- [ ] Health endpoint trả về 200: `GET /health` (hoặc equivalent)
- [ ] Database connection healthy
- [ ] Cache/Redis connection healthy (nếu có)
- [ ] External service integrations healthy

### Critical User Flows

- [ ] [Flow 1 — ví dụ: Login / Auth]
- [ ] [Flow 2 — ví dụ: Create main entity]
- [ ] [Flow 3 — ví dụ: Core business operation]
- [ ] [Flow 4 — ví dụ: Payment / critical path]

### API Sanity

- [ ] `[GET /api/endpoint]` → 200 OK
- [ ] `[POST /api/endpoint]` → 201 Created
- [ ] Auth middleware hoạt động (401 khi không có token)
- [ ] Error responses đúng format

### Performance Sanity

- [ ] Response time < [N]ms cho main endpoints
- [ ] Không có memory leak rõ ràng (check metrics sau 5 phút)
- [ ] Logs không có ERROR/CRITICAL spam

---

## 🔴 Issues Found Post-Deploy

> Điền nếu có issue sau deploy. Để trống nếu clean.

| # | Severity | Description | Status |
|---|----------|-------------|--------|
| 1 | 🔴/🟡/🟢 | [Mô tả issue] | Open / Fixed / Accepted |

---

## 🎯 Verdict

### Deploy Decision: ⬜ **[DEPLOYED / ROLLED BACK / BLOCKED]**

**Reason:** [Lý do — all clear / issue found / blocker]

**Next step:**
- [ ] DEPLOYED → Notify team, monitor 24h, schedule production deploy
- [ ] ROLLED BACK → Document root cause, fix, re-deploy
- [ ] BLOCKED → Fix blockers, re-run `ccdeploy new staging`

---

## 📊 Deploy Summary

| Field | Value |
|-------|-------|
| Environment | Staging |
| Version | v{{VERSION}} |
| Sprint | {{SPRINT_NUMBER}} |
| Deployer | {{DEPLOYER}} |
| Date | {{DATE}} |
| Smoke Test | ✅ Pass / ❌ Fail |
| Verdict | ⬜ PENDING |
| Ready for Prod | ⬜ After [N]h stable on staging |

---

**Signed off by:** {{DEPLOYER}}
**Date:** {{DATE}}

---

## 📝 Notes

[Ghi chú thêm — issues gặp, workarounds, observations]
