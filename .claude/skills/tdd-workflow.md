---
name: tdd-workflow
description: Red-Green-Refactor cycle
when_to_use: Khi viết feature mới hoặc được yêu cầu viết tests
---

## Cycle: RED → GREEN → REFACTOR

RED: Viết test fail trước. Chạy, xác nhận thấy fail message rõ ràng.
GREEN: Viết code minimal nhất để test pass. Không over-engineer.
REFACTOR: Clean up, không thêm feature. Tests vẫn phải pass sau refactor.

## Rules
- Test phải fail vì đúng lý do (không phải syntax error)
- Commit sau mỗi cycle hoàn thành
- Không viết implementation trước test
- Mỗi test test một behavior cụ thể
