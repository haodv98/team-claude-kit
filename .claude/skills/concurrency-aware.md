---
name: concurrency-aware
description: Phân loại SAFE/EXCLUSIVE trước khi thực thi nhiều tasks
---

## SAFE (song song được)
FileRead, Grep, Glob, git log/diff/status, SELECT query, GET requests, lint/typecheck

## EXCLUSIVE (tuần tự)
FileWrite, FileEdit, migration, npm/pnpm install, git commit/push, INSERT/UPDATE/DELETE

Default EXCLUSIVE nếu không chắc.

## Plan trước khi thực hiện
[Batch 1 — parallel] Task A + B + C (đều SAFE)
[Serial] Task D (EXCLUSIVE)
[Serial] Task E (EXCLUSIVE)
[Batch 2 — parallel] Task F + G (SAFE, sau khi D+E xong)

Hỏi confirm plan cho task lớn.
Abort toàn bộ batch nếu EXCLUSIVE bash command fail.
