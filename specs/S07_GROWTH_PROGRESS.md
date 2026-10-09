# S07 — Nhật ký sinh trưởng

**Vị trí:** tab Tiến trình của lô; form dùng chung khi ghi từ công việc. **Quyền:** mọi role nội bộ xem, tạo và sửa.

## Nội dung và form

Card giai đoạn, notes, thời điểm, thumbnail ảnh; mở ảnh xem/phóng to. Server sắp recordedAt giảm dần. Form stage và notes bắt buộc theo app, đều là chuỗi tự do; recordedAt mặc định hiện tại. Có thể ghi **không ảnh** hoặc chọn tối đa 5 ảnh mới JPEG/PNG/WebP, mỗi ảnh ≤5 MiB.

Khi sửa, hiển thị ảnh server hiện có để xem và vùng chọn ảnh mới riêng. Remove trong selector chỉ bỏ ảnh mới chưa gửi; không xóa ảnh đã lưu. PATCH thêm ảnh vào record, không thay thế tất cả ảnh cũ.

## API call

| Method / path | Dữ liệu | Response |
| --- | --- | --- |
| GET /api/cultivation-batches/{id}/growth-progress | Không page/limit | 200 data array gồm images |
| POST /api/cultivation-batches/{id}/growth-progress | multipart/form-data | 201 message/data record |
| PATCH /api/cultivation-batches/{id}/growth-progress/{recordId} | multipart/form-data | 200 message/data record |

Multipart form mẫu (không phải JSON):

```text
stage = Ra quả thể
notes = Mũ nấm phát triển đều
recordedAt = 2026-10-05T01:00:00.000Z
images = <file 1; image/jpeg>
images = <file 2; image/webp>
```

Field `images` lặp cho từng file; 0 ảnh thì không gửi field file. Thư viện tự đặt multipart boundary. Không gửi imageUrl, images JSON, id, batchId hoặc actor/timestamps. ID record/image integer.

Record: `id,batchId,stage,notes,recordedAt,createdAt,updatedAt,createdByUserId,updatedByUserId,images`. Image chứa `id,imageUrl,originalName,mimeType,fileSize` và metadata; ghép imageUrl theo origin server.

Sau mutation refresh record list và lô; từ công việc dùng data record trả về để tự chọn `GROWTH_PROGRESS` evidence. Các lần gửi cũ vẫn hiển thị **snapshot lúc gửi**, không đọc lại record vừa sửa để thay lịch sử.

Ảnh này tách khỏi [gallery lô S19](S19_ENTITY_GALLERY.md). Không có endpoint xóa riêng ảnh growth. Tiến trình công khai chỉ lấy record mới nhất có recordedAt ≤ thời điểm hiện tại, xem [S16](S16_PUBLIC_GROWTH.md).

## Kiểm tra

- [ ] 0 ảnh hợp lệ, >5 ảnh mới/file >5 MiB/sai MIME bị chặn trước request.
- [ ] PATCH giữ ảnh cũ, thêm ảnh mới; ảnh lỗi có placeholder/retry.
- [ ] Snapshot task không đổi sau sửa stage/notes/ảnh record.
- [ ] Record có ngày tương lai không được chọn làm currentProgress công khai.
