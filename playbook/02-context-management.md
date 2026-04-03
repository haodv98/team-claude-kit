# Context Management

## Dấu hiệu context đang rot
- Claude hỏi lại thứ đã giải thích
- Code không follow conventions
- Câu trả lời dài, lặp lại
- Bắt đầu dùng `any` trong TypeScript

## Khi thấy dấu hiệu: dừng ngay
/wrap-session → /clear → load session file → tiếp tục

## Giữ context nhỏ
Chia task lớn thành nhiều sessions nhỏ.
Commit thường xuyên = điểm reset tự nhiên.
Load đúng file, không load hết codebase.

## 5 lớp defense (từ Claude Code architecture)
Layer 1: Truncate output dài — "Chỉ trả 20 dòng đầu"
Layer 2: Xóa tool results cũ, giữ code changes
Layer 3: /wrap-session → /clear khi session > 2h
Layer 4: Session mới nếu Claude bắt đầu quên
Layer 5: Session handover file cho người khác tiếp

## Nguyên tắc quan trọng
Không giải thích thêm khi Claude đang confused — làm worse.
Đừng spam cùng prompt — escalate strategy thay vì retry.
