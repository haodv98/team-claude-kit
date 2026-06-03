# {{PROJECT_NAME}} — Agent Roster

> Xương sống của AI workflow cho project này.
> Cập nhật phần "Team Assignments" sau khi onboard team.

## Stack & Domain

- **Language/Framework:** {{STACK}}
- **Database:** {{DATABASE}}
- **Testing:** {{TESTING}}

## Standard Workflow (mỗi task đều theo)

```
Plan → TDD → Code Review → Security (nếu cần) → Commit
```

1. `/plan` — planner agent: identify deps, risks, phases
2. `/tdd` — tdd-guide: RED → GREEN → REFACTOR
3. `/code-review` — code-reviewer + lang-reviewer: address CRITICAL/HIGH
4. `/security-scan` — security-reviewer (bắt buộc khi có auth/payment/input)
5. Commit theo Conventional Commits

## Agent Roster

| Agent | Trigger | Command |
|-------|---------|---------|
| `planner` | "implement", "add feature", "build", "create" | `/plan` |
| `architect` | "design", "architecture", "ADR", "how to structure" | Prompt directly |
| `tdd-guide` | "tdd", "test first", "write tests for" | `/tdd` |
| `code-reviewer` | "review", "check quality", "before merge" | `/code-review` |
| `security-reviewer` | "security", "vulnerability", "before deploy" | `/security-scan` |
| `build-error-resolver` | "build error", "fix build", "compile error" | `/build-fix` |
| `e2e-runner` | "e2e", "playwright", "browser test" | `/e2e` |
| `database-reviewer` | "schema", "migration", "query review" | Prompt directly |
| `typescript-reviewer` | "type errors", "ts review", "type check" | `/code-review` |

## Multi-Agent Delegation

Dùng `/multi-plan` + `/multi-execute` **chỉ khi**:
- 3+ subtasks độc lập có thể chạy song song
- Cần parallel FE + BE + DB work
- Pre-merge review cần nhiều góc nhìn

**Không dùng cho**: bug fix < 50 lines, docs, config changes.

## Team Assignments

| Area | Lead | Backup | Primary Agents |
|------|------|--------|----------------|
| Frontend | @TBD | @TBD | typescript-reviewer, e2e-runner |
| Backend | @TBD | @TBD | code-reviewer, security-reviewer |
| Database | @TBD | @TBD | database-reviewer |
| DevOps/Infra | @TBD | @TBD | build-error-resolver |

## ECC Commands Reference

```
/plan "feature"        → Orchestrated planning
/tdd "feature"         → TDD workflow RED→GREEN→REFACTOR
/code-review           → Quality + security review
/security-scan         → Vulnerability scan
/e2e                   → Generate E2E tests
/build-fix             → Fix build/type errors
/multi-plan "task"     → Multi-agent decomposition
/multi-execute         → Run orchestrated workflow
/orchestrate           → General multi-agent coordination
/checkpoint            → Save verification state
/wrap-session          → Session-end protocol
```

## API Response Format (enforce across all agents)

```json
// Success
{ "success": true, "data": {}, "meta": { "page": 1, "total": 100, "limit": 20 } }

// Error
{ "success": false, "message": "Validation failed", "statusCode": 400, "errors": [] }
```

## Commit Format

```
feat(scope): add X
fix(scope): resolve Y
refactor(scope): extract Z
test(scope): add coverage for W
docs(scope): update API docs
chore(scope): update deps
```

## Escalation Protocol

Stuck → Sonnet → Sonnet + extended thinking → Opus + think-hard → Human
**Never retry same approach > 2 times.**

## Context Management

- `/compact` khi context > 70%
- `/clear` khi context > 90% → reload CLAUDE.md sau
- `/checkpoint` trước khi clear để save state
