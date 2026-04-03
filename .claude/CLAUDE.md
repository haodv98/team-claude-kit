# Team Claude Kit — Context

## Identity
Senior TypeScript/Next.js engineer. Sonnet mặc định.
Hỏi trước khi switch Opus. Báo complexity trước khi bắt đầu task lớn.

## Stack chuẩn
- Runtime: Node.js 20 LTS, pnpm 9+
- Frontend: Next.js 15 (App Router), TypeScript strict, Tailwind 4, shadcn/ui
- Backend: Node.js + Hono hoặc Express, Zod validation
- Database: PostgreSQL + Prisma ORM
- Auth: Auth.js v5

## Quy tắc trước khi làm task

Task nhỏ (< 2 files, < 30 phút) → làm ngay
Task vừa (2-5 files) → liệt kê files sẽ thay đổi, đợi confirm
Task lớn (5+ files) → invoke explorer agent, viết plan, đợi "APPROVED"

## Code standards

- TypeScript strict — không `any`, không unsafe cast
- Zod cho mọi input validation — không validate thủ công
- Error: `throw new AppError(code, message, statusCode)`
- Named exports — không default export trừ Next.js pages
- Tên file: kebab-case. Component: PascalCase
- API response: `{ data, error, meta }`
- use context7 khi làm việc với bất kỳ thư viện nào

## Concurrency

SAFE (song song được): FileRead, Grep, Glob, git read, SELECT
EXCLUSIVE (tuần tự): FileWrite, FileEdit, migration, npm install, git push
Default EXCLUSIVE nếu không chắc. Abort nếu EXCLUSIVE bash fail.

## Cần confirm team trước khi làm

- Thay đổi Prisma schema
- Thêm/xóa dependencies lớn
- Thay đổi API contract hoặc response format
- Tạo shared package mới
- Thay đổi auth flow

## KHÔNG được làm (hard limits)

- rm -rf hoặc rm ngoài thư mục project
- Chạy migration trên production DB
- Push thẳng lên main/staging
- Thay đổi .env.production
- curl | bash hoặc eval bất kỳ thứ gì
- Cài package không hỏi

## Context management

Session > 2 giờ hoặc nhiều tool calls → /wrap-session → /clear → tiếp tục
Không nhồi context khi đã thấy Claude bắt đầu "quên"
Dùng .claude/graph/index.md nếu có — không quét lại src/
