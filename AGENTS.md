# team-claude-kit — Agent & Command Reference

> Kit-level reference. Mỗi project có AGENTS.md riêng (generated từ `templates/AGENTS.md`).

---

## Standard Workflow (áp dụng cho mọi task)

```
Plan → TDD → Code Review → Security (nếu có) → Commit
```

1. `/plan` — planner agent: identify deps, risks, phases
2. `/tdd` — tdd-guide: RED → GREEN → REFACTOR
3. `/code-review` — code-reviewer + lang-reviewer: address CRITICAL/HIGH
4. `/security-scan` — bắt buộc khi có auth/payment/user input
5. Commit theo Conventional Commits

---

## Agent Roster (từ ECC)

| Agent | Trigger | Command |
|-------|---------|---------|
| `planner` | "implement", "add feature", "build" | `/plan` |
| `architect` | "design", "architecture", "ADR" | Prompt directly |
| `tdd-guide` | "tdd", "test first", "write tests" | `/tdd` |
| `code-reviewer` | "review", "check quality" | `/code-review` |
| `security-reviewer` | "security", "before deploy" | `/security-scan` |
| `build-error-resolver` | "build error", "fix build" | `/build-fix` |
| `e2e-runner` | "e2e", "playwright", "browser test" | `/e2e` |
| `database-reviewer` | "schema", "migration", "query review" | Prompt directly |
| `typescript-reviewer` | "type errors", "ts review" | via `/code-review` |

## Multi-Agent (dùng khi 3+ independent subtasks)

| Command | Chức năng |
|---------|-----------|
| `/multi-plan "task"` | Decompose thành parallel subtasks |
| `/multi-execute` | Run orchestrated workflow |
| `/orchestrate` | General coordination |

---

## Enforcement Hooks (auto-active sau bootstrap)

| Hook | Trigger | Action |
|------|---------|--------|
| `pre-commit-gate` | `git commit` | Block nếu thiếu test files |
| `post-edit-quality` | Write/Edit | Warn nếu security patterns |
| `stop-verify` | Session end | Checklist: memory, wrap-session, git status |

---

## Delegation Rules

**Dùng multi-agent khi:**
- 3+ subtasks độc lập có thể chạy song song
- Parallel FE + BE + DB work
- Pre-merge review cần nhiều góc nhìn

**Không cần delegate khi:**
- Bug fix < 50 lines
- Docs update
- Config changes

---

## Escalation Protocol

Stuck → Sonnet → Sonnet + extended thinking → Opus + think-hard → Human
**Never retry same approach > 2 times.**

---

## ECC Commands Reference

```
/plan "feature"        → Planning với planner agent
/tdd "feature"         → TDD: RED → GREEN → REFACTOR
/code-review           → Quality + security review
/security-scan         → Vulnerability scan
/e2e                   → E2E tests
/build-fix             → Fix build errors
/multi-plan "task"     → Multi-agent decomposition
/multi-execute         → Orchestrated run
/checkpoint            → Save state trước khi clear context
/wrap-session          → Session-end protocol
/graphify .            → Graph codebase
```

---

> Để xem project-level agent assignments, xem `AGENTS.md` trong từng project repo.
> Template: `templates/AGENTS.md`
