---
name: debug-systematic
description: 4-phase debug — root cause trước khi sửa
when_to_use: Bug không rõ nguyên nhân sau 1 lần thử thất bại
paths: ["**/*.ts", "**/*.tsx", "**/*.js"]
---

KHÔNG sửa code trước khi xong Phase 2.

## Phase 1 — Observe
Đọc error đầy đủ. Xác định: ở đâu, khi nào, điều kiện nào.
Reproduce được chưa? Chưa reproduce = không tiếp tục.

## Phase 2 — Hypothesize
Trace call stack ngược từ error.
Liệt kê 2-3 hypothesis. Kiểm tra nhanh từng cái.
Báo cáo: "Root cause có thể là X vì Y. Evidence: Z"

## Phase 3 — Fix (minimal)
Sửa đúng root cause. Không refactor thêm. Không sửa "tiện thể".

## Phase 4 — Verify
Reproduce case gốc → hết chưa? Chạy related tests. Test edge cases.

## Escalation
Attempt 1: Sonnet
Attempt 2: Sonnet + think step by step
Attempt 3: Opus + think hard
Sau 3: Báo cáo đầy đủ, đề xuất human review.

Anti-patterns: random fix, sửa nhiều thứ cùng lúc, không reproduce trước.
