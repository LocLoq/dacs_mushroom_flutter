# S02 — Tổng quan

**Vị trí:** phần đầu tab **Quản lý** khi đã đăng nhập (không có route riêng). **Quyền:** admin, manager, staff. [Quy tắc chung](UI_DESIGN_SPEC.md).

## Nội dung hiện tại

Manager/admin thấy KPI số lô, sản lượng thu hoạch kg, số cơ sở, lô trễ hạn; chip số lượng theo trạng thái lô; panel việc đang mở và năm lô gần nhất. Nút “Quản lý lô” mở danh sách lô. Chip trạng thái mở danh sách lô đã lọc theo trạng thái đó.

Staff thấy tổng số lô từ pagination cùng danh sách lô/việc; **không gọi API reports**. Dashboard không giới hạn dữ liệu thành chỉ các lô được giao. Nhấp công việc mở chi tiết công việc (UUID); nhấp lô mở chi tiết lô (ID số nguyên). Panel việc có nút “Xem tất cả”; với staff, tiêu đề panel lô là “Lô nuôi (tổng số)”.

Panel “Việc cần làm” dùng totalItems của truy vấn việc mặc định: TODO + IN_PROGRESS + PENDING_REVIEW. Chờ duyệt vẫn là việc đang mở; chỉ COMPLETED được coi hoàn thành. Không tự tính tỷ lệ hoàn thành từ năm việc đang hiển thị.

KPI/panel theo lưới linh hoạt; điện thoại hẹp xuống một cột. Mỗi vùng có loading/rỗng/lỗi riêng; kéo xuống (pull-to-refresh) trên tab Quản lý dựng lại và tải lại toàn bộ Tổng quan.

## API call

Gọi song song các request độc lập:

| Method / path | Query | Quyền |
| --- | --- | --- |
| GET /api/cultivation-batches | `page=1&limit=5` | Mọi role nội bộ |
| GET /api/dashboard/tasks | `page=1&limit=5`, không status | Mọi role nội bộ |
| GET /api/reports/overview | `from=YYYY-01-01&to=YYYY-MM-DD&groupBy=month`, không page/limit | Chỉ manager/admin |

Ví dụ `GET /api/reports/overview?from=2026-01-01&to=2026-10-05&groupBy=month`.

Hai list dùng envelope data/pagination. Overview đọc `data.cultivation.batchCount`, `totalHarvestKg`, `facilities`, `overdueBatches`, `statusBreakdown`. Response chi tiết ở [S12](S12_REPORTS.md). Lô “gần nhất” hiện theo thứ tự startDate giảm dần của server, không phải tự sắp theo createdAt.

## Kiểm tra

- [ ] Staff không phát sinh request reports/financial; không hiện KPI giả.
- [ ] Lỗi một vùng không che kết quả vùng khác.
- [ ] PENDING_REVIEW có nhãn “Chờ duyệt”, tính trong số việc đang mở.
- [ ] Chip truyền đúng status, liên kết dùng đúng kiểu ID, refresh lấy dữ liệu mới.
