---
name: db-migration
description: Thay đổi schema an toàn
---

1. Invoke db-migration-advisor agent để phân tích impact
2. Đợi advisor output risk assessment
3. Nếu High risk → confirm team trước
4. Tạo migration file theo advisor template
5. Test migration trên local trước
6. Không chạy trên staging/production mà không có human approval
