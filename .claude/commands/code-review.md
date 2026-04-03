---
name: code-review
description: Review code trước PR
---

Invoke code-reviewer agent để review code hiện tại.
Sau đó invoke verifier agent để chạy tests.

Output tổng hợp:
- Issues critical (phải sửa)
- Issues warning (nên sửa)
- VERDICT: READY / NEEDS WORK
