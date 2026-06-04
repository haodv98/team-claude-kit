# Testing Playbook — Unit, E2E & Automation

> Áp dụng từ đầu sprint. Vai trò: Developer + QA Lead.
> Rule: Unit test chạy **song song** (parallel agents). E2E chạy sau khi staging up.
> Frontend components **BẮT BUỘC** có `data-test-id` trước khi PR merge.

---

## Trước khi bắt đầu

Checklist môi trường:

- [ ] Test framework đã cài (Jest/Vitest cho unit, Playwright/Cypress cho E2E)
- [ ] `data-test-id` lint rule đã active (xem Phase 1)
- [ ] CI pipeline có step riêng cho unit test và e2e test
- [ ] Coverage threshold đã config ≥ 80%

> ⛔ **STOP**: Không viết code production trước khi test framework ready.

---

## Phase 1: Enforce `data-test-id` Convention

### Quy tắc bắt buộc cho Frontend

Mọi interactive component và container có data đều phải có `data-test-id`:

```tsx
// ✅ ĐÚNG
<button data-test-id="submit-login-btn">Đăng nhập</button>
<input data-test-id="email-input" type="email" />
<div data-test-id="user-profile-card">...</div>
<table data-test-id="transaction-table">...</table>

// ❌ SAI — không có data-test-id
<button>Đăng nhập</button>
<input type="email" />
```

### Naming Convention

```
{component}-{element}-{type}

Ví dụ:
- login-form          → form container
- login-email-input   → input trong login form
- login-submit-btn    → button submit
- user-avatar-img     → avatar image
- sidebar-nav-link    → navigation link
- product-list-table  → table hiển thị products
- product-row-{id}    → row theo dynamic ID
```

### ESLint Rule (React/JSX)

Thêm vào `.eslintrc`:

```json
{
  "plugins": ["testing-library"],
  "rules": {
    "testing-library/consistent-data-testid": [
      "warn",
      {
        "testIdPattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
        "testIdAttribute": ["data-test-id"]
      }
    ]
  }
}
```

Hoặc custom rule đơn giản — thêm vào pre-commit hook:

```bash
# Kiểm tra interactive elements thiếu data-test-id
grep -rn "<button\|<input\|<select\|<textarea\|<a " src/components/ \
  | grep -v "data-test-id" \
  | grep -v "//.*<" \
  && echo "⛔ Missing data-test-id found!" && exit 1 \
  || echo "✅ All interactive elements have data-test-id"
```

### Architect Agent Prompt — Audit data-test-id

Chạy trong Claude Code để audit toàn bộ frontend:

```
Act as a frontend QA architect. Audit all React/Vue/Angular components in src/.

For EVERY interactive element (button, input, select, textarea, a, form) and
data container (table, list, card, modal) that is missing data-test-id:

1. List file:line
2. Suggest the correct data-test-id value following the convention:
   {component}-{element}-{type} (kebab-case, lowercase)
3. Output a patch-ready diff

Output format:
MISSING data-test-id:
- src/components/LoginForm.tsx:23 → data-test-id="login-submit-btn"
- src/components/UserCard.tsx:45 → data-test-id="user-profile-card"

Then apply all fixes directly to the files.
```

---

## Phase 2: Unit Testing (Parallel Agents)

### Cấu trúc thư mục

```
src/
├── components/
│   ├── LoginForm/
│   │   ├── LoginForm.tsx
│   │   └── LoginForm.test.tsx    ← unit test cạnh source
├── hooks/
│   ├── useAuth.ts
│   └── useAuth.test.ts
├── utils/
│   ├── formatCurrency.ts
│   └── formatCurrency.test.ts
└── services/
    ├── authService.ts
    └── authService.test.ts
```

### Pattern: TDD với Parallel Agents

Khi implement feature mới, launch **3 agents song song**:

```
Agent 1 — Unit Tests cho Logic/Utils:
"Write unit tests for all pure functions and utilities in [module].
 Follow AAA pattern. Mock external dependencies. Target 100% branch coverage.
 File: src/utils/[module].test.ts"

Agent 2 — Unit Tests cho Components:
"Write unit tests for React components in [module].
 Use Testing Library. Test: render, user interaction, state changes, error states.
 Use data-test-id selectors exclusively (getByTestId).
 File: src/components/[Module]/[Module].test.tsx"

Agent 3 — Unit Tests cho Services/API:
"Write unit tests for service layer in [module].
 Mock HTTP calls with msw or jest.mock. Test: success, error, edge cases.
 File: src/services/[module].test.ts"
```

> **Rule:** 3 agents chạy đồng thời, không chờ nhau. Merge results sau.

### Testing Library — Dùng data-test-id

```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import LoginForm from './LoginForm'

describe('LoginForm', () => {
  it('submit with valid credentials', async () => {
    // Arrange
    const onSubmit = jest.fn()
    render(<LoginForm onSubmit={onSubmit} />)

    // Act — dùng data-test-id, KHÔNG dùng text/class
    await userEvent.type(screen.getByTestId('login-email-input'), 'user@example.com')
    await userEvent.type(screen.getByTestId('login-password-input'), 'password123')
    await userEvent.click(screen.getByTestId('login-submit-btn'))

    // Assert
    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'password123',
    })
  })

  it('shows error on empty submit', async () => {
    render(<LoginForm onSubmit={jest.fn()} />)
    await userEvent.click(screen.getByTestId('login-submit-btn'))
    expect(screen.getByTestId('login-error-msg')).toBeInTheDocument()
  })
})
```

### Coverage Check

```bash
# Chạy với coverage report
npx jest --coverage --coverageThreshold='{"global":{"lines":80}}'

# Hoặc Vitest
npx vitest run --coverage
```

Coverage thresholds trong `jest.config.js`:

```js
module.exports = {
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
}
```

### Architect Agent Prompt — Unit Test Review

```
Act as a senior test engineer. Review the unit tests in [path].

Check for:
1. AAA pattern compliance (Arrange/Act/Assert clearly separated)
2. All data-test-id selectors used (NO text/class/id selectors)
3. Edge cases covered: empty input, null, error states, loading states
4. Mocks properly reset between tests
5. No implementation details tested (test behavior, not internals)
6. Coverage ≥ 80% for branches, lines, functions

For each violation, output:
- file:line
- Issue description
- Fixed code snippet

Then apply fixes directly.
```

---

## Phase 3: E2E Testing (Playwright)

### Cài đặt

```bash
npm install -D @playwright/test
npx playwright install chromium firefox webkit
```

`playwright.config.ts`:

```ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
  ],
})
```

### Cấu trúc E2E

```
e2e/
├── auth/
│   ├── login.spec.ts
│   └── register.spec.ts
├── dashboard/
│   └── dashboard.spec.ts
├── [feature]/
│   └── [feature].spec.ts
└── fixtures/
    └── auth.fixture.ts
```

### E2E Selector Convention — Dùng data-test-id

```ts
// helpers/selectors.ts — centralize tất cả selectors
export const sel = (testId: string) => `[data-test-id="${testId}"]`

// Trong test file
import { sel } from '../helpers/selectors'

test('user can login', async ({ page }) => {
  await page.goto('/login')

  // Dùng data-test-id selector
  await page.fill(sel('login-email-input'), 'user@example.com')
  await page.fill(sel('login-password-input'), 'password123')
  await page.click(sel('login-submit-btn'))

  // Assert redirect và dashboard load
  await page.waitForURL('/dashboard')
  await expect(page.locator(sel('dashboard-header'))).toBeVisible()
})
```

### Critical User Flows — Bắt buộc có E2E

Mỗi flow sau phải có ít nhất 1 happy path + 1 error path:

| Flow | File |
|------|------|
| Authentication (login/logout) | `e2e/auth/login.spec.ts` |
| Registration & Onboarding | `e2e/auth/register.spec.ts` |
| Core business flow (CRUD chính) | `e2e/[feature]/[feature].spec.ts` |
| Payment / Checkout (nếu có) | `e2e/payment/checkout.spec.ts` |
| Role-based access (nếu có) | `e2e/auth/rbac.spec.ts` |

### Playwright Fixtures — Reuse auth state

```ts
// e2e/fixtures/auth.fixture.ts
import { test as base, Page } from '@playwright/test'

export const test = base.extend<{ authenticatedPage: Page }>({
  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login')
    await page.fill('[data-test-id="login-email-input"]', process.env.TEST_USER_EMAIL!)
    await page.fill('[data-test-id="login-password-input"]', process.env.TEST_USER_PASSWORD!)
    await page.click('[data-test-id="login-submit-btn"]')
    await page.waitForURL('/dashboard')
    await use(page)
  },
})
```

### Chạy E2E

```bash
# Local — headless
npx playwright test

# Local — headed (xem browser)
npx playwright test --headed

# Một file cụ thể
npx playwright test e2e/auth/login.spec.ts

# Xem report sau khi chạy
npx playwright show-report
```

### Architect Agent Prompt — E2E Coverage Audit

```
Act as an E2E test architect. Review the application's critical user flows.

1. List ALL user journeys in the app (from specs in contexts/specs/ or from src/)
2. Check which journeys have E2E coverage in e2e/
3. Identify gaps — flows with no E2E test
4. For each gap, generate a complete Playwright test spec using data-test-id selectors

Output:
COVERED: login flow, registration
MISSING E2E:
- Password reset flow → generate e2e/auth/password-reset.spec.ts
- Product checkout flow → generate e2e/payment/checkout.spec.ts

Then generate and write the missing test files.
```

---

## Phase 4: CI Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run test -- --coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v4

  e2e-test:
    runs-on: ubuntu-latest
    needs: unit-test       # E2E chạy sau unit test pass
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npm run build && npm run start &
      - run: npx wait-on http://localhost:3000
      - run: npx playwright test
        env:
          E2E_BASE_URL: http://localhost:3000
          TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

### Gate Rule trong PR

Thêm vào PR template (`PULL_REQUEST_TEMPLATE.md`):

```markdown
## Testing Checklist

- [ ] Unit tests written (hoặc updated) cho tất cả changed logic
- [ ] All new components có `data-test-id` trên interactive elements
- [ ] Coverage ≥ 80% (không giảm từ baseline)
- [ ] E2E test updated nếu user flow thay đổi
- [ ] CI green (unit + e2e)
```

---

## Luồng tổng quan theo Sprint

```
Feature Start
    │
    ▼
Thêm data-test-id vào components  ← Phase 1 (bắt buộc)
    │
    ▼
TDD: Viết test trước, code sau     ← Phase 2 (parallel agents)
    ├── Agent 1: Utils tests
    ├── Agent 2: Component tests
    └── Agent 3: Service tests
    │
    │ (merge khi coverage ≥ 80%)
    ▼
PR Review — checklist tick          ← Gate
    │
    ▼
Staging up → chạy E2E              ← Phase 3
    │
    │ (E2E green)
    ▼
Sprint Audit (ccaudit)             → Deploy Playbook
```

---

## Quick Reference

| Lệnh | Mục đích |
|------|----------|
| `npm test -- --coverage` | Unit test + coverage |
| `npx playwright test` | E2E headless |
| `npx playwright test --headed` | E2E có browser |
| `npx playwright show-report` | Xem E2E report |
| `npx playwright codegen` | Record E2E interactions |
| `grep -rn "data-test-id" src/` | Kiểm tra coverage data-test-id |
