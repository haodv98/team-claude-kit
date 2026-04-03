# Prompt Patterns

## Nguyên tắc
1. Constraint trước, yêu cầu sau
2. Scope cụ thể: file, function, behavior
3. Output format rõ ràng
4. use context7 với thư viện ngoài

## Pattern: Constraint-first
"Đừng tạo file mới, đừng cài package.
Chỉ sửa src/auth/login.ts để thêm rate limiting."

## Pattern: Scope cụ thể
"Trong src/auth/session.ts, function refreshToken():
- Thêm check token expiry
- Return AppError('TOKEN_EXPIRED') nếu hết hạn
- Không thay đổi function signature
use context7 cho Auth.js v5"

## Pattern: Plan-then-execute
"Trước khi code, liệt kê:
1. Files nào thay đổi
2. Breaking change nào
3. Migration cần gì
Đợi confirm rồi mới bắt đầu."

## Pattern: Follow existing
"Đọc src/api/users.ts và src/api/products.ts.
Thêm /api/orders theo đúng pattern của 2 file trên."

## Anti-patterns
✗ "Fix everything"  →  ✓ "Fix lỗi X trong file Y"
✗ "Make it better"  →  ✓ "Cải thiện performance của function Z"
✗ Paste toàn bộ codebase  →  ✓ Paste file liên quan
✗ "You decide"  →  ✓ Đưa 2-3 options, hỏi trade-off
