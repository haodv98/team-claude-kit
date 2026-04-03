---
name: wrap-session
description: Lưu context trước khi kết thúc session
---

Tạo session summary và lưu vào file. Bao gồm:

1. Đã hoàn thành: tasks xong trong session này
2. Đang dở: task chưa xong, đang ở bước nào
3. Bước tiếp theo: cụ thể cần làm gì khi mở session mới
4. Quyết định quan trọng: architectural decisions, workarounds
5. Files đã thay đổi: danh sách file chính đã edit
6. Gotchas: bugs đang track, issues cần nhớ

Lưu vào: .claude/sessions/YYYY-MM-DD-HHMM.md

In đường dẫn file để dễ load lại.
