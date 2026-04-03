# CLAUDE.md — Project Brain

@AGENTS.md

## Stack

- **API**: NestJS + TypeScript (port 3001)
- **Web**: Next.js 16 + React 19 + App Router (port 3000)
- **Database**: PostgreSQL via Prisma ORM
- **Testing**: Vitest (unit/integration) + Playwright (e2e)
- **Monorepo**: Turborepo + pnpm workspaces

## Key Commands

```bash
pnpm dev              # start all apps
pnpm dev:api          # start api only
pnpm dev:web          # start web only
pnpm build            # build all
pnpm test             # run all tests
pnpm test:e2e         # playwright e2e
pnpm lint             # eslint all
pnpm typecheck        # tsc --noEmit all
pnpm db:migrate       # prisma migrate dev
pnpm db:generate      # prisma generate
pnpm db:studio        # prisma studio
pnpm db:seed          # seed database
```

## Architecture — Critical Rules

- API layer (NestJS): Controller → Service → Repository → Prisma
- NEVER skip layers. No Prisma in controllers. No logic in controllers.
- Next.js: Server Components by default. `'use client'` only when necessary.
- Next.js 16: `params` are Promises — always `await params`
- API response envelope: `{ success, data, meta }` / `{ success, message, statusCode }`

## File Ownership (agent zones)

| Zone           | Path                         | Agent        |
| -------------- | ---------------------------- | ------------ |
| API modules    | `apps/api/src/modules/**`    | backend dev  |
| API common     | `apps/api/src/common/**`     | backend dev  |
| DB schema      | `apps/api/prisma/**`         | db agent     |
| Web pages      | `apps/web/src/app/**`        | frontend dev |
| Web components | `apps/web/src/components/**` | frontend dev |
| Shared types   | `packages/shared/**`         | architect    |

## Rules (modular — loaded by path)

Full rules in `.cursorrules` (shared with Cursor).
Claude-specific modular rules in `.claude/rules/`.

## Context Budget

- Load only active feature files
<!-- - /compact at 70% context
- /clear + reload CLAUDE.md at 90%+ -->
- Use /checkpoint before clearing

## ECC Commands Reference

```
/plan "task"          → planner agent → implementation plan
/tdd "feature"        → tdd-guide agent → RED→GREEN→REFACTOR
/code-review          → code-reviewer + typescript-reviewer
/e2e                  → e2e-runner → Playwright tests
/build-fix            → build-error-resolver
/multi-plan "task"    → decompose into parallel subtasks
/multi-execute        → dispatch agents
/orchestrate          → general coordination
/security-scan        → AgentShield (102 rules)
/learn                → extract patterns from session
/checkpoint           → save current state
/instinct-status      → view learned patterns
```
