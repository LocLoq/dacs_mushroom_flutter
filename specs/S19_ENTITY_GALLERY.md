# S19 — Gallery cơ sở, giống nấm và lô

**Vị trí:** bottom sheet chi tiết cơ sở/giống; tab **Ảnh** của lô. **Quyền:** khách xem ảnh public, token hợp lệ xem tất cả ảnh và metadata; manager/admin mutation. API GET xác thực tùy chọn.

## 1. Component và dữ liệu

Gallery dùng chung, list phân trang 10 ảnh/trang, thumbnail, caption, nhãn “Ảnh bìa”, xem/phóng to. Chỉ gọi khi mở chi tiết/tab; list cơ sở/giống/lô chỉ dùng coverImageUrl/imageCount từ response parent.

ID parent/image là integer. GalleryImage có `id,imageUrl,originalName,mimeType,fileSize,caption,isCover,isPublic,uploadedByUserId,createdAt` và FK parent tương ứng. GET sort **isCover giảm dần, createdAt tăng dần, ID tăng dần**.

Rỗng có placeholder; ảnh lỗi có placeholder (không có nút tải lại riêng; mở lại màn hoặc làm mới để tải lại). Resolve URL với origin server; không nối /api vào /uploads. Giống dùng imageUrl cũ làm dự phòng theo response khi chưa có ảnh gallery. Ảnh legacy không tự trở thành GalleryImage có ID để sửa/xóa.

Gallery lô tách hoàn toàn với images của growth record [S07](S07_GROWTH_PROGRESS.md).

## 2. API call đủ ba resource

| Resource | Collection GET/POST | Item PATCH/DELETE |
| --- | --- | --- |
| Cơ sở | `/api/production-facilities/{id}/images` | `/api/production-facilities/{id}/images/{imageId}` |
| Giống | `/api/mushroom-species/{id}/images` | `/api/mushroom-species/{id}/images/{imageId}` |
| Lô | `/api/cultivation-batches/{id}/images` | `/api/cultivation-batches/{id}/images/{imageId}` |

| Method | Body / query | Response / quyền |
| --- | --- | --- |
| GET | page=1, limit=10, tối đa 50 | 200 data/pagination, mọi role nội bộ |
| POST | Multipart images + caption tùy chọn | 201 message/data **array ảnh**, manager/admin |
| PATCH | JSON caption và/hoặc isCover | 200 message/data image, manager/admin |
| DELETE | Không body | 200 message, manager/admin |

## 3. Upload, chú thích, bìa và xóa

“Tải ảnh” mở selector/form: **1–5 ảnh** JPEG/PNG/WebP, mỗi ảnh ≤5 MiB; caption chung trim ≤500 ký tự. Field images lặp theo file, chỉ một field caption. Không gửi isCover/URL/metadata trong upload. 0 ảnh không hợp lệ (khác growth POST cho phép 0 ảnh). Tên file backend tối đa 255 ký tự.

```text
POST /api/production-facilities/1/images
Content-Type: multipart/form-data; boundary=<thư viện tạo>
images = <ảnh 1; image/jpeg>
images = <ảnh 2; image/png>
caption = Khu nuôi trồng
```

Chú thích của một ảnh:

```json
{"caption": "Khu chăm sóc sau cải tạo"}
```

Xóa chú thích phải gửi null:

```json
{"caption": null}
```

Chọn bìa:

```json
{"isCover": true}
```

Không gửi isCover=false: backend trả 400. Chọn bìa bỏ cờ bìa ảnh khác cùng gallery trong transaction. Gallery chưa có ảnh: ảnh đầu của upload đầu tiên tự làm bìa. Xóa ảnh phải xác nhận; nếu xóa bìa server chọn ảnh còn lại cũ nhất làm bìa, nếu hết ảnh trả về gallery rỗng.

Staff không có nút tải/chú thích/chọn bìa/xóa, vẫn xem/phóng to/phân trang. Nút khóa khi mutation đang chạy; lỗi giữ form và không giả cập nhật.

## 4. Refresh và nghiệm thu

Sau mutation reload gallery page 1, GET parent detail và reload list parent để cover/count đồng bộ. Catalog giữ query khi reload list. Chi tiết lô giữ tab/khung nội dung khi refetch; không che gallery đang mở bằng loading toàn màn.

- [ ] Cả ba resource xem/phân trang đúng, không gọi gallery cho mọi row list.
- [ ] Upload 1–5 hợp lệ; 0/>5/sai MIME/quá dung lượng bị chặn.
- [ ] Caption giới hạn, xóa gửi null, chọn bìa gửi true.
- [ ] Xóa bìa có ảnh thay thế từ server; xóa cuối gallery rỗng, giống có thể dùng legacy fallback.
- [ ] Gallery/detail/list đồng bộ; staff chỉ xem; ảnh growth và ảnh gallery lô độc lập.

## Trạng thái công khai của ảnh

Upload/sửa có công tắc Công khai; thẻ ảnh có nhãn Công khai/Riêng tư. Frontend mặc định public cho ảnh giống nấm, private cho ảnh cơ sở/lô. POST multipart isPublic=true/false áp dụng cho mọi ảnh trong lần tải; PATCH JSON isPublic: boolean đổi từng ảnh. Sau mutation reload gallery và cover/count của parent.

GET không token chỉ trả id,imageUrl,caption,isCover của ảnh isPublic=true. Các field metadata vắng mặt không gây lỗi giao diện. GET với token hợp lệ trả đầy đủ ảnh/metadata. Từ điển dùng chế độ public kể cả khi đang có token. Ảnh private dùng fetch bytes với Authorization đúng origin, không gửi token qua redirect, bỏ provider khi đăng xuất/đổi server.
