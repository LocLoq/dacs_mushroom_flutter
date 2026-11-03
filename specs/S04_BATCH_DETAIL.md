# S04 — Chi tiết lô

**Vị trí:** màn đẩy từ danh sách lô, Tổng quan, báo cáo tài chính hoặc công việc; ID integer dương. **Quyền:** mọi role nội bộ; sửa lô mọi role, xóa chỉ manager/admin.

## Bố cục hiện tại

Trang cuộn dọc: mã lô, giống/cơ sở, nút Sửa lô/Xóa lô; panel trạng thái và các giai đoạn, ngày bắt đầu/dự kiến thu hoạch, số bịch, giá thể, ghi chú; nút “Trang công khai” mở [S16](S16_PUBLIC_GROWTH.md) với mã lô điền sẵn.

Các chip giai đoạn là thông tin, không phải nút tự đổi status. FAILED có thông báo riêng. App không có panel chi tiết cố định bên phải ở desktop.

Tab bằng ChoiceChip/Wrap: **Tiến trình** (mặc định), **Chăm sóc**, **Thu hoạch**, **Ảnh**; manager/admin có thêm **Tài chính**. Lazy load lần đầu mở tab, giữ nội dung tab đã tải. Gallery Ảnh khác ảnh nhật ký Tiến trình.

## API call

| Method / path | Quyền / dữ liệu |
| --- | --- |
| GET /api/cultivation-batches/{id} | Mọi role; 200 data lô và quan hệ |
| PUT /api/cultivation-batches/{id} | Mọi role; body form S03, 200 message/data |
| DELETE /api/cultivation-batches/{id} | Manager/admin; 200 message |

GET trả thông tin lô, facility, mushroom, coverImageUrl/imageCount; không lấy gallery từ ảnh lồng của record. Form sửa dùng field và enum [S03](S03_BATCH_LIST.md); PUT chỉ field có thể chỉnh, không gửi metadata. Staff có nút Sửa lô theo code và quyền backend hiện tại.

Xóa phải xác nhận tên/mã lô, cảnh báo bản ghi liên quan có thể bị xóa; thành công về list và tải lại. Backend là nơi quyết định dữ liệu phụ thuộc; lỗi giữ trang và hiển thị message.

## API theo tab và refresh

| Tab | Spec / request đầu tiên |
| --- | --- |
| Tiến trình | [S07](S07_GROWTH_PROGRESS.md): GET /api/cultivation-batches/{id}/growth-progress |
| Chăm sóc | [S05](S05_CARE_LOGS.md): GET /api/cultivation-batches/{id}/care-logs |
| Thu hoạch | [S06](S06_HARVESTS.md): GET /api/cultivation-batches/{id}/harvests |
| Ảnh | [S19](S19_ENTITY_GALLERY.md): GET /api/cultivation-batches/{id}/images |
| Tài chính | [S18](S18_FINANCIALS.md): GET summary và danh sách tài chính |

Nút làm mới trên AppBar tải lại chi tiết lô; mỗi tab tự tải lại sau thao tác ghi của chính nó. Ghi care/growth/harvest tải lại danh sách tương ứng và lô; nếu tab tài chính đã tải, refresh summary/dữ liệu tài chính. Sau gallery mutation tải lại gallery, chi tiết và list để cập nhật cover/count. Khi tải lại lô sau thao tác gallery, giữ nội dung và vị trí tab thay vì che toàn bộ trang.

## Kiểm tra

- [ ] GET lỗi có retry; 404 không dựng lô rỗng như thật.
- [ ] Tab chưa mở không tải API không cần thiết; staff không gọi financial.
- [ ] Thu hoạch finalize cập nhật trạng thái từ server; tab Ảnh không trộn ảnh growth.
- [ ] Sửa/xóa thành công refresh đúng; gallery không làm mất tab đang xem.
