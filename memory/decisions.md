# Technical Decisions

Log các quyết định kỹ thuật quan trọng của project XX.

---

### [2026-03] Stack chính

**Context:** Khởi tạo project XX  
**Decision:**
- Backend: NestJS + TypeScript, REST API, Bull+Redis cho jobs
- Frontend: Next.js App Router + React, TanStack Query + Zustand, Tailwind + shadcn
- Database: PostgreSQL + Prisma ORM (ưu tiên so với MySQL vì JSONB và analytics)
- Cache/Queue: Redis
- File storage: S3-compatible object storage
- Monorepo: Turborepo + pnpm workspaces  
**Consequences:** Toàn bộ code TypeScript, nhất quán giữa API và Web.

---

### [2026-03] Kiến trúc NestJS

**Context:** Cần chuẩn hóa layer trong API  
**Decision:** Controller → Service → Repository → Prisma. KHÔNG được bỏ qua layer.  
**Consequences:** No Prisma in controllers. No logic in controllers.

---

### [2026-03] API Response Format

**Context:** Cần chuẩn hóa API response  
**Decision:**
- Single resource: `{ "data": <entity> }`
- List + pagination: `{ "data": [], "meta": { page, limit, total } }`
- Auth login/register/refresh: `{ accessToken, refreshToken, expiresIn, user }` (không wrap trong `data`)
- Error: `{ statusCode, code (UPPER_SNAKE_CASE), message, errors[] }`  
**Consequences:** Tất cả API phải tuân thủ format này.

---

### [2026-03] Auth strategy

**Context:** Cần auth cho multi-tenant  
**Decision:** JWT + refresh token. Phase 3 sẽ migrate sang IDP (Keycloak preferred).  
**Consequences:** Hiện tại self-managed JWT; cần thiết kế để dễ swap sau.

---

### [2026-03] RBAC & Tenant scoping

**Context:** Multi-outlet, multi-role  
**Decision:** Dùng PermissionService cho role checks. Không duplicate ad-hoc role logic.  
**Consequences:** Outlet scoping thông qua `X-Organization-Id` / `X-Outlet-Id` header.

---
