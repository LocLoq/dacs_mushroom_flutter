# S15 — Nhật ký hệ thống

**Vị trí:** Quản lý → Nhật ký hệ thống (mục chỉ hiện với manager/admin). **Quyền:** **manager và admin**; staff không được xem.

## Giao diện

List readonly 20/trang. Filter: actorUserId, action, entityType, entityId, outcome, statusCode, từ/đến ngày. Action/entityType là chuỗi đối chiếu chính xác ở backend; UI hiện mã hành động nguyên văn (chưa dịch nhãn). Bộ lọc là các ô nhập nhỏ áp dụng khi bấm Áp dụng hoặc Enter, kèm chip Mọi kết quả/Thành công/Thất bại và hai ActionChip chọn ngày; “từ ngày” phải ≤ “đến ngày”.

Mỗi dòng là một card: hành động, người thực hiện, đối tượng/ID, kết quả/HTTP, thời gian (không có DataTable). Actor null hiển thị “Hệ thống”. Nhấp mở AlertDialog cuộn từ **row hiện có**, gồm hành động, method, path, entityType/entityId và thời gian; không phát sinh GET detail.

## API call

| Method / path | Query / response |
| --- | --- |
| GET /api/admin/audit-logs | page=1, limit=20 và filter tùy chọn → 200 data/pagination |

Filter:

| Field | Giá trị |
| --- | --- |
| actorUserId | Integer dương |
| action, entityType | Chuỗi exact |
| entityId | Chuỗi; có thể UUID hoặc ID số được biểu diễn string |
| outcome | SUCCESS hoặc FAILURE |
| statusCode | Integer dương |
| from, to | ISO UTC từ đầu/cuối ngày local thiết bị; from ≤ to |

Backend tối đa 100/trang. Query sai → 400, giữ filter để sửa. Row chứa `id,actorUserId,actorUsername,actorRole,action,entityType,entityId,method,path,statusCode,outcome,durationMs,createdAt` và metadata nếu server có. Không có API sửa/xóa audit, GET audit/{id} hoặc công cụ quản trị hệ thống tại màn này.

Ví dụ `GET /api/admin/audit-logs?page=1&limit=20&action=TASK_SUBMIT&entityType=Task&outcome=SUCCESS`.

Báo cáo Hoạt động ở [S12](S12_REPORTS.md) là màn riêng, chỉ filter ngày; không tự dùng toàn bộ filter audit log làm report query.

## Kiểm tra

- [ ] Manager vào được; staff bị chặn và không gọi API.
- [ ] Filter đúng exact/string/number, reset page khi đổi.
- [ ] Detail không gọi endpoint chưa có; actor null và action mới hiển thị được.
- [ ] Không hiển thị thao tác mutation hoặc hứa chức năng audit chưa triển khai.
