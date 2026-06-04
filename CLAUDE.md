# team-claude-kit — Claude Context

> Project-level override. Global context tại ~/.claude/CLAUDE.md vẫn áp dụng.
> Sửa file này để customize riêng cho project này.

---

## CRITICAL: Frontend Testing Rules (Non-negotiable)

### `data-test-id` — Bắt buộc 100%

Khi implement bất kỳ màn hình, component, hoặc UI element mới:

**PHẢI thêm `data-test-id` cho:**
- Mọi interactive element: `<button>`, `<input>`, `<select>`, `<textarea>`, `<a>`
- Container chứa data: `<form>`, card, modal, table, list
- Element hiển thị trạng thái: error message, loading indicator, empty state

**Naming convention — kebab-case:**
```
{component}-{element}-{type}

Ví dụ:
login-email-input       → input email trong LoginForm
login-submit-btn        → button submit
user-profile-card       → card hiển thị user
transaction-list-table  → table danh sách giao dịch
error-message-text      → thông báo lỗi
loading-spinner         → loading indicator
```

**Code mẫu:**
```tsx
// ✅ ĐÚNG
<button data-test-id="login-submit-btn">Đăng nhập</button>
<input data-test-id="login-email-input" type="email" />
<div data-test-id="user-profile-card">...</div>

// ❌ SAI — không chấp nhận trong PR
<button>Đăng nhập</button>
<input type="email" />
```

**Trong test — chỉ dùng `data-test-id` selector:**
```tsx
// Testing Library
screen.getByTestId('login-submit-btn')

// Playwright
page.locator('[data-test-id="login-submit-btn"]')
```

> ⛔ PR thiếu `data-test-id` trên interactive elements = BLOCK merge.
> Xem chi tiết: `playbook/12-testing-playbook.md`

