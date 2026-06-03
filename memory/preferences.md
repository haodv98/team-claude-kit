# Project Preferences

## Coding Style

- **Language:** TypeScript cho tất cả file mới
- **Database columns:** snake_case
- **API response:** phải đúng format chuẩn (xem decisions.md)
- **Components:** functional components trong React
- **Next.js 16:** `params` là Promise — luôn phải `await params`
- **Server Components by default** — `'use client'` chỉ khi thực sự cần

## Tools & Libraries

| Domain | Choice |
|--------|--------|
| API Framework | NestJS |
| ORM | Prisma |
| Queue | Bull + Redis |
| Frontend state | TanStack Query + Zustand |
| UI | Tailwind CSS + shadcn/ui |
| Testing unit/integration | Vitest |
| Testing E2E | Playwright |
| Monorepo | Turborepo + pnpm workspaces |
| Logger | F3sLoggerService (không dùng console.log trực tiếp) |
| Date util | `common/utils/date.util` |

## Workflow

- **Branching:** feature branches từ `develop`; main branch là `develop`
- **Commit format:** Conventional commits (`feat:`, `fix:`, `chore:`, `ci:`, v.v.)
- **Agent zones:** xem CLAUDE.md > File Ownership
- **Codebase navigation:** dùng `/graphify .` → đọc `graphify-out/GRAPH_REPORT.md`

## Do / Don't

### ✅ DO
- Luôn đi qua đúng layer: Controller → Service → Repository → Prisma
- Dùng `PermissionService` cho RBAC checks
- Dùng `F3sLoggerService` cho logging
- Dùng `common/utils/date.util` cho date handling
- Validate input tại system boundaries
- Tham chiếu `memory/decisions.md` trước khi đề xuất hướng mới

### ❌ DON'T
- KHÔNG dùng Prisma trong controllers
- KHÔNG để business logic trong controllers
- KHÔNG log passwords hoặc tokens
- KHÔNG duplicate ad-hoc role logic ngoài PermissionService
- KHÔNG dùng `'use client'` nếu không cần thiết trong Next.js
- KHÔNG hardcode secrets trong code
