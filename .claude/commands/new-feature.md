---
name: new-feature
description: Planning và triển khai feature mới theo chuẩn team
---

Trước khi viết code:

## Bước 1 — Phân tích (tối đa 3 câu hỏi)
Feature ảnh hưởng đến phần nào? Cần API mới không? Schema change không?

## Bước 2 — Kiểm tra conflict
Đọc CLAUDE.md. Liệt kê files sẽ thay đổi.
Nếu có schema change → DỪNG, cần confirm team.

## Bước 3 — Plan (checklist)
- [ ] Files cần tạo
- [ ] Files cần sửa
- [ ] Tests cần viết
- [ ] Migration cần tạo

Hỏi "Plan này ổn không?" trước khi code.

## Bước 4 — Implement
use context7 cho thư viện liên quan.
Types trước, implementation sau.
Commit từng bước nhỏ.

## Bước 5 — Self-review
TypeScript errors? Zod validation? Error handling? any?
Invoke verifier agent trước khi báo xong.
