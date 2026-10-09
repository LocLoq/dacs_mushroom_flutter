# S05 — Nhật ký chăm sóc

**Vị trí:** tab Chăm sóc trong chi tiết lô; cùng form có thể mở từ công việc. **Quyền:** mọi role nội bộ được xem và ghi.

## Giao diện

Danh sách card ghi actionType, thời điểm và notes; sắp recordedAt giảm dần từ server. Không dùng bảng phân trang hay timeline riêng trong app hiện tại. Loading/rỗng/lỗi có nút ghi chăm sóc/tải lại.

Form: **Loại hành động** và **Nội dung** bắt buộc theo app; ngày ghi nhận tùy chọn, app đặt mặc định hiện tại. actionType là **chuỗi tự do**, không có enum WATERING/FERTILIZING bắt buộc; giá trị cũ WATERING được dịch “Tưới nước”.

## API call

| Method / path | Body / response |
| --- | --- |
| GET /api/cultivation-batches/{id}/care-logs | 200 `{data:[CareLog]}`, không page/limit |
| POST /api/cultivation-batches/{id}/care-logs | JSON, 201 message/data record |

```json
{
  "actionType": "Tưới nước",
  "notes": "Tưới đều bề mặt, kiểm tra độ ẩm",
  "recordedAt": "2026-10-05T01:30:00.000Z"
}
```

Không gửi batchId trong body (đã nằm ở path), id hoặc metadata. Bỏ recordedAt thì backend đặt thời điểm hiện tại. Record có `id,batchId,actionType,notes,recordedAt,createdAt,createdByUserId,updatedByUserId`; ID record là integer. CareLog hiện không có updatedAt.

Sau ghi tại lô: tải lại care list và chi tiết lô. Sau ghi tại công việc: dùng **data record server trả về** để tự chọn minh chứng `{type:"CARE_LOG",recordId:id}`, không tìm bằng chuỗi nội dung hoặc ID giả. Công việc chưa gắn lô cần chọn lô trước, xem [S17](S17_TASK_EVIDENCE.md).

Không có sửa/xóa care-log trong API/UI hiện tại. Không thêm nút hoặc giả định PUT/DELETE endpoint.

## Kiểm tra

- [ ] ActionType/notes trống không gửi; lỗi giữ input.
- [ ] GET giải mã array không đòi pagination.
- [ ] POST thành công hiển thị record server; từ công việc chọn đúng ID.
- [ ] Staff ghi được; danh sách rỗng khác lỗi API.
