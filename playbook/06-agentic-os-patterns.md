# Agentic OS Patterns — Áp dụng thực tế

Chắt lọc từ 18 patterns từ 513K dòng source code Claude Code.

## 8 nguyên tắc cốt lõi

1. Safe-by-default — khi không chắc: exclusive, block, ask
2. Observe behavior, không trust labels (API hay Claude nói)
3. Escalate, đừng retry cùng strategy
4. Constraint bằng code/config, không chỉ bằng lời
5. Defense-in-depth — mỗi guardrail cần ít nhất 2 lớp
6. Circuit breaker — mỗi recovery path chỉ chạy 1 lần
7. "Quên conversation, nhớ lessons"
8. Trách nhiệm không ủy quyền — human approve gate quan trọng

## Áp dụng key patterns

P1 Derived flag: đừng tin Claude nói "xong" — kiểm tra output thật
P2 Escalating recovery: Sonnet → Sonnet+think → Opus+think hard → human
P3 Death spiral: khi Claude loạn, DỪNG, không thêm context
P4 Concurrency: phân loại SAFE/EXCLUSIVE trước khi làm nhiều tasks
P6 Coordinator: bạn = coordinator (plan+review), Claude = worker (implement)
P7 Defense-in-depth: mỗi agent có 2 lớp (system prompt + tool subset)
P9 Context defense: 5 lớp escalating — xem playbook/02-context-management.md
P11 Classification: chỉ định hành động cụ thể trong CLAUDE.md, không chỉ tool
P13 Conditional skills: paths frontmatter để skill tự load đúng lúc
P15 TIP→Skill: pattern dùng 3 lần → tạo skill → ccsync --push
