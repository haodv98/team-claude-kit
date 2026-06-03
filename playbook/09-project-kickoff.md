# Project Kickoff Playbook — Team Lead Guide

> Chạy sau khi `bootstrap.sh --project <path>` hoàn tất.
> Thực hiện theo thứ tự. STOP tại điểm xác nhận spec trước khi tiếp tục.

---

## Trước khi bắt đầu

Checklist xác nhận bootstrap đã xong:
- [ ] `cchealth` pass trên máy team lead
- [ ] `.claude/` có agents/, skills/, commands/, hooks/
- [ ] `contexts/`, `memory/`, `docs/`, `tasks/` đã tồn tại
- [ ] `CLAUDE.md` và `AGENTS.md` đã tạo

---

## Phase 0: Chuẩn bị Context

### Bước 1: Nạp specs/PRDs vào project

```bash
cp /path/to/prd.pdf contexts/specs/
cp /path/to/requirements.md contexts/specs/
cp /path/to/wireframes/ contexts/specs/wireframes/
```

Hoặc tạo specs thủ công trong `contexts/specs/`.

> **Format hỗ trợ:** Markdown, PDF, docx, hình ảnh wireframe
> **Rule:** Không sửa file gốc trong `contexts/specs/` — chỉ thêm, không xóa.

### Bước 2: Graph codebase (chỉ với existing repos)

Trong Claude Code:
```
/graphify .
```

Đọc `graphify-out/GRAPH_REPORT.md` để nắm cấu trúc hiện tại.

> **Bỏ qua bước này** nếu đây là dự án mới hoàn toàn.

---

## Phase 1: Phân tích Specs

### Bước 3: Phân tích specs với Architect Agent

Trong Claude Code, gửi prompt sau (thay thế phần trong []):

```
You are the architect for [PROJECT_NAME].

Read ALL files in contexts/specs/ thoroughly. Then produce a complete analysis:

1. **Functional Requirements** (numbered list, specific and testable)
2. **Non-functional Requirements** (performance, security, scalability, etc.)
3. **System Components** (what services/modules are needed)
4. **Data Model Overview** (key entities and relationships)
5. **Integration Points** (external APIs, third-party services)
6. **UNCLEAR ITEMS** — flag any ambiguous, missing, or contradictory spec items
   Format each as: UNCLEAR-NNN: [description] | Impact: High/Med/Low | Needs: [what info is needed]
7. **Technical Risks** (top 5, with mitigation ideas)

Save complete output to contexts/analysis.md
```

### Bước 4: Review UNCLEAR items

1. Mở `contexts/analysis.md`
2. Tìm section **UNCLEAR ITEMS**
3. Với mỗi UNCLEAR item:
   - **Confirm được ngay** → Cập nhật spec trong `contexts/specs/`, đánh dấu resolved
   - **Cần hỏi stakeholder** → Gửi email/Slack, ghi lại vào `contexts/clarifications/TBD.md`
   - **Có thể defer** → Ghi vào `contexts/clarifications/TBD.md` với owner và deadline

**Format TBD.md:**
```markdown
| ID | Item | Owner | Due | Status |
|----|------|-------|-----|--------|
| TBD-001 | [Unclear spec] | @name | Phase 2 | Open |
```

> ⛔ **STOP**: Không tiếp tục Bước 5 nếu còn UNCLEAR items với Impact: High chưa resolved.
> Chỉ defer items Impact: Low hoặc không block Phase 1.

---

## Phase 2: Kiến trúc

### Bước 5: Tạo ADRs với Architect Agent

Trong Claude Code:

```
Based on contexts/analysis.md and contexts/specs/:

Identify the top architectural decisions that must be made before development starts.
Focus on: framework/language choices, data model approach, API design, auth strategy,
deployment architecture, key integration patterns, testing strategy.

For each decision, create an ADR using the template at contexts/adrs/ADR-000-template.md.
Save as: contexts/adrs/ADR-NNN-[short-title].md (start from ADR-001)

Present each ADR for review before creating the next one.
Minimum: 5 ADRs for typical projects. Cover all major tech decisions.
```

**Review process cho mỗi ADR:**
- Team lead review và confirm
- Discuss trade-offs với team nếu cần
- Mark status `Accepted` trước khi tiếp tục

**ADRs bắt buộc:**
- ADR-001: Framework/Stack selection
- ADR-002: Database design approach
- ADR-003: Authentication strategy
- ADR-004: API design (REST/GraphQL/tRPC)
- ADR-005: Deployment architecture

### Bước 6: Tạo Architecture Overview

Trong Claude Code:

```
Based on the accepted ADRs in contexts/adrs/ and contexts/analysis.md:

Create a comprehensive architecture overview document using the template at docs/architecture.md.
Fill in all sections with real decisions from the ADRs.
Include system diagram (ASCII), technology stack table, key components, data model overview.

Save to docs/architecture.md
```

Review và confirm với team trước khi tiếp tục.

---

## Phase 3: Planning

### Bước 7: Tạo Roadmap

Trong Claude Code:

```
Based on contexts/specs/, contexts/analysis.md, and confirmed ADRs:

Create a development roadmap using the template at docs/roadmap.md.
Requirements:
- 3-5 phases with clear goals and exit criteria
- Realistic duration estimates (use story points or t-shirt sizes)
- Clear milestones per phase
- Dependencies between phases explicitly noted
- Risk register for each phase
- Out of scope for v1.0 explicitly listed

Phase 1 should be achievable in [X weeks] with a team of [N].
Save to docs/roadmap.md
```

**Team lead review:**
- Timelines realistic?
- Dependencies correct?
- Phase 1 scope achievable for first sprint?
- Confirm với stakeholders nếu cần

### Bước 8: Breakdown tasks cho Phase 1

Trong Claude Code:

```
Based on docs/roadmap.md Phase 1 deliverables:

Break down ALL work into discrete, actionable tasks.
For each task:
- Title: verb-first, clear outcome (e.g., "Implement user authentication with JWT")
- Effort: XS (<2h) | S (2-4h) | M (4-8h) | L (1-2d) | XL (2-5d)
- Priority: Critical (blocks others) | High | Medium | Low
- Dependencies: which tasks must complete first
- Acceptance criteria: 2-4 testable criteria
- Technical notes: files to change, patterns to follow

Order tasks by execution sequence (respecting dependencies).
Save each as: tasks/phase-1/TASK-NNN-[short-title].md
Use tasks/TASK-000-template.md as format reference.

Total Phase 1 tasks should be completable in [X sprints] of [Y weeks].
```

**Review task breakdown:**
- Mỗi task có thể làm trong 1 ngày hoặc ít hơn? (nếu L/XL, xem xét split)
- Dependencies đúng chưa?
- Có task nào bị miss không?
- Assign initial owners vào AGENTS.md

---

## Phase 4: Team Setup

### Bước 9: Update CLAUDE.md

Thêm vào section "Project-Specific Rules" trong `CLAUDE.md`:

```markdown
## Project Context

**Goal:** [One-sentence goal]
**Phase:** Phase 1 — [Phase name]
**Tech Stack:** [Stack summary]

## Key Architectural Decisions

- ADR-001: [Decision summary]
- ADR-002: [Decision summary]
- ADR-003: [Decision summary]

## Domain Rules

- [Domain-specific constraint 1]
- [Domain-specific constraint 2]

## Current Sprint Focus

- [What Phase 1 Sprint 1 is building]
```

### Bước 10: Update AGENTS.md

Điền vào phần Team Assignments:

```markdown
## Team Assignments

| Area | Lead | Backup | Primary Agents |
|------|------|--------|----------------|
| Frontend | @tên | @tên | typescript-reviewer, e2e-runner |
| Backend | @tên | @tên | code-reviewer, security-reviewer |
| Database | @tên | @tên | database-reviewer |
```

### Bước 11: Onboard team members

Mỗi team member chạy:

```bash
# 1. Bootstrap kit trên máy của họ
bash bootstrap.sh --target claude --languages typescript

# 2. Install project scope
bash bootstrap.sh --project /path/to/project

# 3. Verify
cchealth

# 4. Start working
ccclaim TASK-NNN [file1 file2]
ccstart
```

---

## Phase 5: First Sprint

### Bước 12: Bắt đầu Sprint 1

Team lead tạo sprint backlog:

```bash
# Claim các critical path tasks
ccclaim TASK-001 tasks/phase-1/TASK-001-*.md
```

Trong Claude Code:

```
Review tasks/phase-1/ — identify the 5-7 critical path tasks for Sprint 1.
These should be: foundational (others depend on them), achievable in 1 sprint, 
no external dependencies unresolved.

Present sprint plan: task list ordered by execution, total effort, 
which tasks can run in parallel, which must be sequential.
```

### Bước 13: Thiết lập Daily Workflow

Mỗi thành viên:

```bash
# Sáng: briefing + check tasks
ccmorning

# Trước khi làm task:
ccclaim TASK-NNN
ccstart

# Trong session: làm theo /tdd → /code-review
# Cuối ngày:
ccunclaim TASK-NNN
cceod
```

---

## Kickoff Checklist

### Context ✓
- [ ] contexts/specs/ có đầy đủ specs/PRDs
- [ ] contexts/analysis.md được tạo và reviewed
- [ ] Tất cả UNCLEAR items Impact: High đã resolved
- [ ] contexts/clarifications/TBD.md có các deferred items

### Architecture ✓
- [ ] Tối thiểu 5 ADRs được tạo và accepted
- [ ] docs/architecture.md hoàn chỉnh
- [ ] Team đã review và confirm architecture

### Planning ✓
- [ ] docs/roadmap.md approved
- [ ] tasks/phase-1/ có tất cả Phase 1 tasks
- [ ] Effort estimates review xong
- [ ] Dependencies đúng

### Team Setup ✓
- [ ] CLAUDE.md cập nhật project context
- [ ] AGENTS.md cập nhật team assignments
- [ ] Tất cả team members chạy cchealth ✅
- [ ] Sprint 1 backlog ready

---

## Prompts Ready-to-Use

Copy và paste những prompts này vào Claude Code tại các bước tương ứng.

### Prompt: Review toàn bộ specs
```
Read and summarize all files in contexts/specs/.
What are we building? Who are the users? What are the most critical features?
What's NOT in scope for v1.0?
```

### Prompt: Tìm conflicting requirements
```
Review contexts/analysis.md and contexts/specs/.
Find any requirements that conflict with each other.
Find any requirements that are technically infeasible or very risky.
List them with suggested resolutions.
```

### Prompt: Estimate Phase 1 effort
```
Review tasks/phase-1/*.md.
Estimate total effort in developer-days.
Assuming a team of [N] developers, how many sprints of [Y weeks] would Phase 1 take?
What's the critical path?
```

### Prompt: Risk assessment
```
Given contexts/analysis.md and contexts/adrs/:
What are the top 5 risks that could derail Phase 1?
For each risk: probability (H/M/L), impact (H/M/L), and mitigation plan.
```

---

## Tham khảo

- `playbook/01-prompt-patterns.md` — Prompt engineering
- `playbook/02-context-management.md` — Context window management
- `playbook/05-team-workflows.md` — Team coordination
- `playbook/07-daily-workflow.md` — Daily workflow detail
- `playbook/08-onboarding.md` — Onboarding new team members
- `contexts/adrs/ADR-000-template.md` — ADR format
- `tasks/TASK-000-template.md` — Task format
- `docs/roadmap.md` — Roadmap template
