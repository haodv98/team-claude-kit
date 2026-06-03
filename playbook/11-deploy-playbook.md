# Deploy Playbook — Staging & Production

> Chạy sau khi sprint audit complete (`ccaudit`).
> Vai trò: Team Lead / DevOps Lead.
> Tool: `ccdeploy` — xem `docs/DEPLOY-GUIDE.md` sau khi install project scope.

---

## Deploy Pipeline Tổng Quan

```
Sprint Done
    │
    ▼
ccaudit new          ← Sprint-end QA audit
    │
    │ verdict: CONDITIONAL/APPROVED
    ▼
ccdeploy new staging ← Gate check + deploy staging
    │
    │ DEPLOYED + stable ≥24h
    ▼
ccdeploy new production ← Stricter gate + deploy production
    │
    ▼
Monitor 24h → close sprint
```

**Rule:** Không skip stage. Staging trước, production sau. Không exception.

---

## Phase 1: Deploy Staging

### Bước 1: Kiểm tra điều kiện tiên quyết

```bash
# Verify audit đã done và CONDITIONAL/APPROVED
ccaudit list
ccaudit summary

# Verify CI green
git log --oneline -5
```

Điều kiện bắt buộc:
- Audit verdict ≠ REJECTED
- CI pipeline green
- Tất cả sprint MUST FIX items đã merge

> ⛔ **STOP**: Không deploy nếu audit REJECTED hoặc CI đang đỏ.

### Bước 2: Tạo staging deploy gate

```bash
cd /path/to/project
ccdeploy new staging
```

Wizard hỏi:
- **Sprint #**: số sprint
- **Version**: semantic version (e.g. `1.2.3`)
- **Deployer**: tên người deploy

Record tạo tại: `deploys/staging/YYYY-MM-DD-vX.Y.Z.md`

### Bước 3: Tick pre-deploy checklist

```bash
ccdeploy open staging
```

Tick từng mục trong **Pre-Deploy Checklist**:
- CI/CD section
- Quality Gate section (link audit file)
- Database section (migrations)
- Configuration section
- Rollback Plan section

> ⛔ **STOP**: Không thực hiện deploy nếu còn mục chưa tick.

### Bước 4: Thực hiện deploy

Điền deploy command vào section **Deploy Execution** của file, sau đó chạy:

```bash
# Ví dụ pattern — thay bằng command thực của project
docker pull registry/project:v1.2.3
docker-compose up -d --no-deps app

# Hoặc k8s:
kubectl set image deployment/app app=registry/project:v1.2.3

# Hoặc PM2:
pm2 reload ecosystem.config.js

# Chạy migrations nếu có:
npm run migrate:deploy
```

Ghi lại **Started at** và **Completed at** trong file.

### Bước 5: Smoke test

Tick từng mục trong **Post-Deploy Smoke Test**:

```bash
# Health check
curl -s https://staging.yourapp.com/health | jq .

# API sanity
curl -s -H "Authorization: Bearer $TOKEN" \
  https://staging.yourapp.com/api/v1/[endpoint]
```

Dùng Claude Code để assist smoke test:

```
Chạy smoke test cho staging deploy v{VERSION}:
1. Kiểm tra health endpoint trả về 200
2. Test auth flow: login → get token → access protected endpoint
3. Test [critical flow 1]
4. Test [critical flow 2]
Báo cáo: PASS / FAIL cho từng flow, kèm response status codes.
```

### Bước 6: Điền verdict staging

Sau smoke test xong, cập nhật verdict trong file:

| Kết quả smoke test | Verdict |
|--------------------|---------|
| Tất cả pass | `DEPLOYED` |
| Minor issues (không block users) | `DEPLOYED` + ghi notes |
| Major issues (users bị ảnh hưởng) | `ROLLED BACK` |

Cập nhật dòng `**Status:**` và `**Deploy Decision:**` trong file.

---

## Phase 2: Deploy Production

### Bước 7: Verify staging stable

Trước khi deploy production, staging phải stable **ít nhất 24 giờ**:

```bash
# Xem staging deploy record
ccdeploy open staging

# Check staging deploy status
ccdeploy status
```

Điều kiện bắt buộc cho production:
- Staging verdict: `DEPLOYED` (không phải ROLLED BACK)
- Thời gian từ staging deploy ≥ 24 giờ
- Audit verdict: **APPROVED** (không chấp nhận CONDITIONAL)
- Không có ERROR/CRITICAL logs trong 24h staging

> ⛔ **HARD STOP**: Production cần APPROVED (không phải CONDITIONAL). Nếu audit CONDITIONAL → fix issues → re-run `ccaudit new` → lấy APPROVED → mới deploy production.

### Bước 8: Notify stakeholders

Trước deploy production:

```bash
# Dùng Claude Code để draft thông báo
claude --print "Draft deploy notification cho team:
- Project: [NAME]
- Version: v[X.Y.Z]
- Deploy window: [HH:MM - HH:MM, timezone]
- Changes: [summary từ sprint]
- On-call: [tên]
- Rollback plan: [N minutes]
Format: Slack message, ngắn gọn."
```

### Bước 9: Tạo production deploy gate

```bash
ccdeploy new production
```

Script tự động:
- Kiểm tra staging đã deploy (hỏi confirm)
- Pre-fill audit ref và staging deploy ref
- Tạo `deploys/production/YYYY-MM-DD-vX.Y.Z.md`

### Bước 10: Tick production pre-deploy checklist

```bash
ccdeploy open production
```

Tick **toàn bộ** checklist (stricter hơn staging):
- Staging Verification section (stable ≥24h)
- Quality Gate section (APPROVED required)
- Database section (migration tested on staging)
- Change Management section (on-call notified)
- Rollback Plan section (must be complete)

> ⛔ **HARD STOP**: Production checklist phải 100% tick. Không có exception.

### Bước 11: Thực hiện production deploy

Deploy trong window đã approve. On-call phải available.

```bash
# Chạy trong change window
[production deploy command]

# Monitor real-time trong 10 phút đầu
tail -f /var/log/app.log | grep -E "ERROR|CRITICAL|WARN"
```

**Rollback threshold**: Nếu trong **10 phút đầu** có:
- Error rate > [N]%
- Response time P95 > [N]ms
- Critical user flow bị broken

→ **Rollback ngay, không chờ investigate**.

### Bước 12: Smoke test production

Chạy ngay sau deploy (trong 10 phút):

```bash
# Production health
curl -s https://yourapp.com/health

# Critical flows (dùng test account, không dùng real user data)
```

### Bước 13: Monitor 24h

Update section **Post-Deploy Monitoring** trong file mỗi N giờ:

```bash
ccdeploy open production
# Điền metrics vào bảng monitoring: error rate, P95 latency, active users
```

### Bước 14: Close sprint

Sau 24h stable:

```bash
# Xem toàn bộ deploy status
ccdeploy status

# Final summary
ccaudit summary
```

Commit tất cả deploy records:

```bash
git add deploys/
git commit -m "chore: sprint-N deploy records (staging + production v[VERSION])"
```

---

## Rollback Runbook

### Khi nào rollback?

| Signal | Action |
|--------|--------|
| Error rate > threshold trong 10 phút đầu | Rollback ngay |
| Critical user flow broken | Rollback ngay |
| Data corruption risk | Rollback ngay + stop writes |
| Performance degradation > 50% | Evaluate → likely rollback |
| Minor cosmetic issues | Monitor, hotfix sau |

### Cách rollback

**Application:**

```bash
# Docker
docker-compose down && docker pull registry/project:v[PREV] && docker-compose up -d

# k8s
kubectl rollout undo deployment/app

# PM2
pm2 stop app && pm2 start ecosystem.config.js --env [prev-env]
```

**Database (nếu có migration):**

```bash
# Chạy rollback migration — PHẢI có script đã chuẩn bị trước
npm run migrate:rollback
# Hoặc
python manage.py migrate app [prev_migration]
```

**Sau rollback:**
1. Verify service restored: health check + smoke test
2. Update verdict trong deploy file: `ROLLED BACK`
3. Notify team + stakeholders
4. Document root cause trong file notes
5. Schedule post-mortem nếu production incident

---

## Các tình huống đặc biệt

### Hotfix (không qua sprint)

```bash
# Tạo deploy gate riêng cho hotfix
ccdeploy new staging
# Version: X.Y.Z+1-hotfix
# Checklist rút gọn: CI + smoke test + deploy
# Sau staging stable (1-2h thay vì 24h cho hotfix critical)
ccdeploy new production
```

### Schema migration không-downtime

Trước khi deploy app:
1. Deploy migration (backward-compatible): add column, index
2. Deploy app với code đọc cả old + new column
3. Deploy migration phase 2: remove old column
4. Ghi rõ 3-phase strategy vào deploy notes

### Feature flags

Dùng feature flag để decouple deploy khỏi release:
- Deploy code với flag OFF
- Smoke test
- Turn flag ON → gradual rollout (1% → 10% → 100%)
- Ghi lại flag state trong deploy file

---

## Prompts Claude Code sẵn dùng

### Kiểm tra readiness trước deploy

```
Review sprint này để xác định deploy readiness:
1. Tất cả PRs trong scope đã merge chưa?
2. Breaking changes nào cần notify users?
3. DB migrations có backward-compatible không?
4. Feature flags nào cần configure?
5. External dependencies có thay đổi không?
Báo cáo: READY / NOT READY + danh sách items cần làm.
```

### Generate release notes

```
Dựa trên git log từ [prev-tag] đến HEAD, tạo release notes cho v[VERSION]:
- New features (feat commits)
- Bug fixes (fix commits)
- Breaking changes (breaking commits)
- Performance improvements (perf commits)
Format: Markdown, user-facing language (không phải technical jargon).
```

### Post-deploy check

```
Post-deploy check cho v[VERSION] trên [staging/production]:
1. Kiểm tra health endpoint: [URL]
2. Test auth flow
3. Test [critical flow]
4. Check error logs trong 5 phút qua
Báo cáo: HEALTHY / DEGRADED / DOWN + chi tiết.
```

---

## Deploy Cadence

| Thời điểm | Action |
|-----------|--------|
| Sprint kết thúc | `ccaudit new` → audit |
| Audit CONDITIONAL/APPROVED | `ccdeploy new staging` |
| Staging +24h stable | `ccdeploy new production` |
| Production +24h stable | Close sprint, commit records |
| Hotfix bất kỳ lúc | `ccdeploy new staging` → `ccdeploy new production` (1-2h) |

---

## Tham khảo

- `playbook/10-sprint-audit-playbook.md` — Sprint-end QA audit (chạy trước)
- `playbook/05-team-workflows.md` — Git + PR workflow
- `playbook/07-daily-workflow.md` — Daily workflow
- `templates/deploy/staging.md` — Staging gate template
- `templates/deploy/production.md` — Production gate template
- `deploys/` — Tất cả deploy records của project
