<!-- DEPLOY VARS (auto-filled by `ccdeploy new production`):
     {{PROJECT_NAME}} {{VERSION}} {{SPRINT_NUMBER}} {{DEPLOYER}} {{DATE}} {{AUDIT_FILE}} {{STAGING_DEPLOY_FILE}} -->

# Production Deploy Gate

## {{PROJECT_NAME}} — v{{VERSION}} → Production

**Deployer:** {{DEPLOYER}}
**Date:** {{DATE}}
**Sprint:** {{SPRINT_NUMBER}}
**Audit Ref:** {{AUDIT_FILE}}
**Staging Ref:** {{STAGING_DEPLOY_FILE}}
**Status:** ⬜ **PENDING**

---

## ⚠️ Production Deploy — Elevated Risk

> Deploy lên production. Mọi thay đổi ảnh hưởng trực tiếp đến end users.
> Thực hiện ngoài giờ cao điểm. Có on-call sẵn sàng.

---

## 📋 Pre-Deploy Checklist

> ⛔ **HARD STOP** nếu bất kỳ mục nào fail. Không exception.

### Staging Verification (Required)

- [ ] Staging deploy DEPLOYED (không phải ROLLED BACK): `{{STAGING_DEPLOY_FILE}}`
- [ ] Staging đã stable ít nhất **24 giờ** sau deploy
- [ ] Smoke test trên staging đã pass hoàn toàn
- [ ] Không có ERROR/CRITICAL trong staging logs trong 24h qua
- [ ] Performance metrics trên staging trong ngưỡng chấp nhận được

### Quality Gate (Stricter than Staging)

- [ ] Sprint audit verdict: **APPROVED** (không chấp nhận CONDITIONAL cho production)
- [ ] Audit ref: `{{AUDIT_FILE}}`
- [ ] Security score ≥ 80/100
- [ ] Tất cả MUST FIX và HIGH PRIORITY items đã fix

### Database

- [ ] Migration đã chạy thành công trên staging
- [ ] Migration rollback đã test trên staging (dry-run verified)
- [ ] Database backup trước deploy: `[backup location/command]`
- [ ] Estimated migration time: `[N minutes]`
- [ ] Migration có thể chạy không downtime? ✅/❌

### Configuration

- [ ] Production environment variables đã verify (không dùng staging values)
- [ ] Production API keys / secrets đúng (không phải sandbox)
- [ ] Feature flags configured cho production
- [ ] CDN / cache invalidation plan (nếu có static assets thay đổi)

### Change Management

- [ ] Stakeholders đã notify về deploy window
- [ ] On-call engineer đã được inform và sẵn sàng
- [ ] Deploy window đã approve: `[HH:MM - HH:MM, timezone]`
- [ ] Maintenance window cần thiết? ✅/❌ → [duration nếu có]

### Rollback Plan (Mandatory)

- [ ] Rollback version confirmed: `v[PREV_VERSION]`
- [ ] Rollback command tested trên staging:
  ```bash
  # [Rollback command]
  ```
- [ ] DB rollback script ready và tested:
  ```bash
  # [DB rollback command nếu có migration]
  ```
- [ ] Rollback time estimate: `[N minutes]`
- [ ] Rollback decision threshold: "Roll back nếu [condition] trong vòng [N minutes]"

---

## 🚀 Deploy Execution

**Target:** Production environment
**Deploy method:** `[docker/k8s/PM2/Vercel/manual]`
**Deploy window:** `[HH:MM - HH:MM]`

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
- [ ] Post-migration data validation: [OK / N/A]

---

## ✅ Post-Deploy Smoke Test

> Chạy **ngay lập tức** sau deploy. Phải hoàn thành trong vòng 10 phút.

### Health Checks

- [ ] Health endpoint: `GET /health` → 200 OK
- [ ] Database connection: healthy
- [ ] Cache connection: healthy (nếu có)
- [ ] External integrations: healthy

### Critical User Flows (Production)

- [ ] [Flow 1 — Happy path quan trọng nhất]
- [ ] [Flow 2 — Revenue-critical flow]
- [ ] [Flow 3 — Auth / access control]
- [ ] [Flow 4 — Data write operation]

### Production-Specific Checks

- [ ] SSL certificate valid
- [ ] DNS resolution đúng
- [ ] CDN serving đúng version
- [ ] Error rate trong Monitoring/Grafana: < threshold `[N]%`
- [ ] Response time P95: < `[N]ms`

### Alert Verification

- [ ] Monitoring alerts active (không bị silence từ deploy)
- [ ] Error budget không vượt SLO
- [ ] Không có spike trong error rate sau deploy

---

## 🔴 Issues Found Post-Deploy

> Điền ngay khi phát hiện. Thời gian quyết định rollback: `[N minutes]`.

| Time | Severity | Description | Impact | Action |
|------|----------|-------------|--------|--------|
| [HH:MM] | 🔴/🟡/🟢 | [Mô tả] | [Users affected] | [Fix/Rollback/Monitor] |

### Rollback Decision Log

- **Decision time:** [HH:MM]
- **Decision maker:** [Name]
- **Decision:** ✅ Continue / 🔴 Rollback
- **Reason:** [Lý do]

---

## 🎯 Verdict

### Deploy Decision: ⬜ **[DEPLOYED / ROLLED BACK]**

**Reason:** [All clear / Root cause nếu rollback]

**If ROLLED BACK:**
- [ ] Rollback executed at: [HH:MM]
- [ ] Service restored at: [HH:MM]
- [ ] Root cause identified: [Yes / Investigating]
- [ ] Post-mortem scheduled: [Yes / No]

---

## 📊 Deploy Summary

| Field | Value |
|-------|-------|
| Environment | Production |
| Version | v{{VERSION}} |
| Sprint | {{SPRINT_NUMBER}} |
| Deployer | {{DEPLOYER}} |
| Date | {{DATE}} |
| Deploy Duration | [N minutes] |
| Downtime | [N minutes / Zero] |
| Smoke Test | ✅ Pass / ❌ Fail |
| Verdict | ⬜ PENDING |
| Rollback Time | [N/A / N minutes] |

---

## 📈 Post-Deploy Monitoring (24h)

> Theo dõi trong 24h sau deploy. Update section này.

| Time | Error Rate | P95 Latency | Active Users | Notes |
|------|-----------|-------------|--------------|-------|
| +1h | [N]% | [N]ms | [N] | |
| +4h | [N]% | [N]ms | [N] | |
| +24h | [N]% | [N]ms | [N] | |

**24h Status:** ✅ Stable / ⚠️ Issues / 🔴 Incident

---

**Signed off by:** {{DEPLOYER}}
**Date:** {{DATE}}

---

## 📝 Notes & Lessons Learned

[Ghi chú — issues gặp, workarounds, cải tiến cho deploy lần sau]

### Lessons Learned

- [Lesson 1 — nếu có]
- [Lesson 2]
