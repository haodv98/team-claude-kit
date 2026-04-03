---
name: adaptive-thinking
description: Quyết định khi nào bật thinking và dùng model nào
---

## Decision matrix

Không cần thinking (Sonnet, mặc định):
- CRUD, API endpoints thông thường
- UI components theo pattern sẵn có
- Fix TypeScript/lint errors
- Viết tests cho code sẵn có
- Refactor nhỏ trong 1 file

Thinking nhẹ — Sonnet + "think step by step":
- Task đụng ≥ 3 files không liên quan
- Debug lỗi không rõ nguyên nhân sau 2 lần thử
- Performance optimization
- Thiết kế API mới

Thinking sâu — Opus + "think hard":
- Quyết định kiến trúc ảnh hưởng nhiều module
- Security-critical code (auth, payment)
- Migration phức tạp
- Bug intermittent khó reproduce

## Báo cáo khi bắt đầu task lớn
Complexity: [Low/Medium/High]
Files affected: [số ước tính]
Risk: [Low/Medium/High]
Model: [Sonnet/Opus]
Thinking: [None/Light/Deep]
Lý do: [1 câu]

Hỏi confirm nếu khuyến nghị Opus.
