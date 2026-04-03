# Project: REAL ESTATE MANAGER

## Stack

- Language: TypeScript / NestJS
- Framework: Next.js 16 (React 19) + App Router
- Database: PostgreSQL (Prisma ORM)
- Testing: Vitest + Playwright

## Project Structure

src/
app/ ← Next.js pages (Frontend agent owns)
api/ ← Route handlers (Backend agent owns)
lib/ ← Shared utilities (read-only for all agents)
db/ ← Prisma schema + migrations (DB agent owns)
tests/
unit/ ← Vitest unit tests
e2e/ ← Playwright E2E tests

## Workflow: Plan → TDD → Review → Ship

### Standard workflow for every feature

1. **Plan** → `planner` agent: identify deps, risks, phases
2. **TDD** → `tdd-guide` agent: RED→GREEN→REFACTOR
3. **Review** → `code-reviewer` + `typescript-reviewer`: address CRITICAL/HIGH first
4. **Security** → `security-reviewer` before merge
5. **Commit** → conventional commits, comprehensive PR summary

## ECC Commands Reference

/plan "feature" → Orchestrated planning với planner agent
/tdd "feature" → TDD workflow: RED→GREEN→REFACTOR
/code-review → Quality + security review
/e2e → Generate Playwright E2E tests
/build-fix → Fix build/type errors tự động
/multi-plan "task" → Multi-agent task decomposition
/multi-execute → Run orchestrated multi-agent workflow
/orchestrate → General multi-agent coordination
/security-scan → AgentShield vulnerability scan
/learn → Extract patterns từ session hiện tại
/checkpoint → Save verification state
/verify → Run verification loop

## Agent Delegation Rules

Orchestrate sub-agents khi:

- Task có 3+ independent subtasks
- Cần parallel FE + BE + DB work
- Code review trước khi merge

Không cần delegate khi:

- Bug fix đơn giản < 50 lines
- Documentation update
- Config changes

## Code Standards (enforced by rules/)

- TDD mandatory: tests trước khi implement
- 80% coverage minimum
- No console.log trong production code
- Atomic commits: one logical change per commit
- Conventional commits: feat/fix/docs/refactor/test

## Context Management

<!-- - /compact khi context > 70%
- /clear khi context > 90%, sau đó reload CLAUDE.md -->

- Dùng /checkpoint để save state trước khi clear

---

## Agent Roster & Triggers

| Agent                  | Trigger Phrases                                     | Tools                   |
| ---------------------- | --------------------------------------------------- | ----------------------- |
| `planner`              | "implement", "add feature", "build", "create"       | Read, Grep, Glob, Write |
| `architect`            | "design", "architecture", "how to structure", "ADR" | Read, Grep, Glob, Write |
| `tdd-guide`            | "tdd", "test first", "write tests for"              | Read, Write, Bash       |
| `code-reviewer`        | "review", "check quality", "before merge"           | Read, Grep, Glob        |
| `typescript-reviewer`  | "type errors", "ts review", "type check"            | Read, Grep, Glob, Bash  |
| `security-reviewer`    | "security", "vulnerability", "before deploy"        | Read, Grep, Glob        |
| `build-error-resolver` | "build error", "fix build", "compile error"         | Read, Write, Bash       |
| `e2e-runner`           | "e2e", "playwright", "browser test"                 | Read, Write, Bash       |
| `database-reviewer`    | "schema", "migration", "query review"               | Read, Grep, Glob        |

---

## API Response Format (enforced by all agents)

```json
{
  "success": true,
  "data": {},
  "meta": { "page": 1, "total": 100, "limit": 20 }
}
```

```json
{
  "success": false,
  "message": "Validation failed",
  "statusCode": 400,
  "errors": [{ "field": "email", "message": "Invalid email" }]
}
```

## Commit Format

```
feat(scope): description
fix(scope): description
refactor(scope): description
test(scope): description
docs(scope): description
chore(scope): description
```

Types: feat | fix | refactor | docs | test | chore | perf | ci

## Git Workflow

Sau mỗi task hoàn thành:

1. Suggest tên branch theo format: <type>/<ticket>-<description>
2. Stage changes phù hợp (không stage file không liên quan)
3. Generate commit message theo Conventional Commits
4. Push lên remote với -u origin <branch>

Branch naming:

- feat/ → tính năng mới
- fix/ → bug fix
- refactor/ → refactor
- Luôn kebab-case, tối đa 50 ký tự

Commit rules:

- Imperative mood
- Max 72 ký tự dòng đầu
- Body giải thích WHY nếu change phức tạp
- Footer Refs: <ticket> nếu có ticket ID trong branch name
