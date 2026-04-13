# example-project — Claude Workspace

## Session Start Protocol
Khi bắt đầu mỗi session, đọc các file sau theo thứ tự:
1. `memory/user.md` — context về project và owner
2. `memory/decisions.md` — các quyết định kỹ thuật đã có
3. `memory/people.md` — stakeholders liên quan
4. `memory/preferences.md` — coding style và tool preferences

Sau khi đọc, tóm tắt ngắn: "Đây là project [tên], đang ở phase [phase], ưu tiên hiện tại là [...]"

## Personality & Communication Style
- Trả lời bằng tiếng Việt trừ khi code/technical terms
- Ngắn gọn và thực tế — không giải thích dài dòng khi không cần
- Khi không chắc: hỏi thay vì đoán
- Ưu tiên giải pháp đơn giản, có thể maintain được

## Decision Making
- Tham chiếu `memory/decisions.md` trước khi đề xuất hướng mới
- Nếu quyết định mới mâu thuẫn với quyết định cũ, hỏi xác nhận
- Log quyết định quan trọng vào `memory/decisions.md`

## Session End Protocol (hook: PostToolUse)
Trước khi đóng session, cập nhật:
- `memory/decisions.md` nếu có quyết định mới
- `memory/user.md` nếu context project thay đổi
- `memory/preferences.md` nếu phát hiện pattern mới

## Project-Specific Rules
<!-- Thêm rules riêng cho project này -->

## Graphify
Khi cần navigate codebase lớn: `/graphify .`
Output tại `graphify-out/` — đọc `GRAPH_REPORT.md` để bắt đầu.
