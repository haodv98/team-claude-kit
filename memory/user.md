# User & Project Context

## Project

**Tên:** F3S — FnB Smart Supporting System  
**Mã:** dng.pj0064.miraifnb  
**Owner:** Hảo Văn

## Project Goal

Hệ thống quản lý vận hành F&B end-to-end:  
`Supplier → PO → Nhập kho → Tồn kho → Công thức → POS sales → Cost engine → Dashboard lợi nhuận`

Mục tiêu cốt lõi:
- Kiểm soát dòng nguyên liệu, giảm food cost & waste
- Insight lợi nhuận real-time, chuẩn hóa vận hành

## Target Users (Personas)

| Vai trò | Quan tâm |
|---------|---------|
| Owner / Investor | Dashboard KPI, margin, so sánh outlet |
| Store Manager | Vận hành ngày, kiểm soát tồn kho |
| Kitchen Manager | Công thức, waste, nguyên liệu |
| Purchasing Staff | PO, GRN, nhà cung cấp |
| Accountant | Chi phí, báo cáo tài chính |
| System Admin | Cấu hình hệ thống, tài khoản |

## Success Metrics (KPIs)

- Food Cost %
- Waste %
- Inventory Turnover
- Gross Margin per Dish
- Daily Net Profit

## Current Phase

**Phase 1 – Pilot** (single chain / internal restaurant-bar)  
→ Tất cả milestone M1–M8 đã phát triển xong.  
→ Trạng thái hiện tại: **Demo readiness** cho Owner Dashboard với dữ liệu iPOS.

### Trạng thái chi tiết (cập nhật 2026-03)

| Hạng mục | Trạng thái |
|----------|------------|
| PRD / Architecture / WBS | ✅ Hoàn thành |
| M1 → M8-UI development | ✅ Đã thực hiện |
| Demo readiness (Owner Dashboard) | 🟡 GO có điều kiện |
| QA + rehearsal demo | 🟡 8/8 P0 endpoints pass; còn 1 mismatch auth refresh |

### Blocker còn lại để GO tuyệt đối

1. Sửa `POST /api/v1/auth/refresh` trả `200` thay vì `201`
2. Rerun QA smoke 8 endpoint + auth để chốt PASS hoàn toàn

## Phases Roadmap

| Phase | Scope |
|-------|--------|
| Phase 1 | Pilot (single chain / internal restaurant-bar) — **đang ở đây** |
| Phase 2 | Mở rộng thêm outlet/chains |
| Phase 3 | SaaS commercialization + IDP (Keycloak) |
