# S20 — Từ điển nấm (danh mục của dịch vụ AI)

**Vị trí:** tab **Từ điển**. **Quyền:** công khai, không cần đăng nhập, không gắn Authorization. [Quy tắc chung](UI_DESIGN_SPEC.md).

Đây là danh mục **của dịch vụ AI nhận diện** (các loài mô hình biết nhận ra), **khác** danh mục giống nấm nghiệp vụ ở [S08](S08_MUSHROOM_SPECIES.md) (dữ liệu của API Node, có CRUD, ảnh gallery và enum khả năng ăn 5 mức). Hai nguồn độc lập; Từ điển chỉ có cờ độc/không độc.

## Giao diện và hành vi

- Tiêu đề “Từ điển nấm”, dòng tóm tắt `{total} loài · {safe} ăn được · {poisonous} có độc`, nút làm mới; kéo xuống cũng tải lại.
- Ô tìm kiếm theo tên thường gọi hoặc tên khoa học, lọc ngay khi gõ (không gọi lại API); nút xóa nhanh.
- Hàng chip lọc: **Tất cả**, **Ăn được**, **Nấm độc**.
- **Lưới thẻ** (tối đa 230 px mỗi thẻ, tỉ lệ 0,8): phần trên là ảnh/hình minh họa kèm huy hiệu **An toàn** hoặc **Có độc** (có icon và chữ, không chỉ màu), phần dưới là tên và tên khoa học (nghiêng). Rỗng thì hiện hình nấm và gợi ý đổi từ khóa.
- Nhấn thẻ mở **bottom sheet chi tiết**: ảnh đầu 190 px, tên, tên khoa học, khối kết luận có màu (“Loài nấm có độc tố nguy hiểm” / “Loài nấm an toàn / ăn được”), đoạn mô tả chung và nút Đóng. Nội dung mô tả là câu chung theo nhóm độc/an toàn, **không phải** dữ liệu riêng của từng loài.

## Nguồn dữ liệu

| Method / path | Ghi chú |
| --- | --- |
| GET `{AI base}/api/mushrooms/catalog` | Dịch vụ AI FastAPI; timeout ngắn |

Response: `{ total, poisonous_count, safe_count, mushrooms: [ {name, scientific_name, is_poisonous, image_url?} ] }`. `is_poisonous` chấp nhận boolean, 1/0 hoặc chuỗi `"true"`. Nếu không tải được, app dùng **danh mục dự phòng đóng gói sẵn** gồm 16 loài (10 ăn được, 6 độc) để màn hình vẫn dùng được khi offline; đây là dữ liệu tham khảo cố định, không phải kết quả nhận diện.

## Ảnh đại diện từng loài

Thứ tự ưu tiên, bước lỗi tự rơi xuống bước kế tiếp, **không bao giờ hiện ô ảnh vỡ**:

1. `image_url` (hoặc `image`, `thumbnail`) do backend trả về: URL đầy đủ `http(s)://…` hoặc đường dẫn tương đối (`/media/…`) được ghép với Backend URL của dịch vụ AI; trong lúc tải hiện hình nấm vẽ sẵn.
2. Ảnh đóng gói trong app `assets/mushrooms/{khóa}.jpg`, với **khóa = tên khoa học viết thường, mọi ký tự ngoài `a–z0–9` thành `_`, cắt `_` ở hai đầu** (ví dụ `Auricularia auricula-judae` → `auricularia_auricula_judae.jpg`). Thư mục có `README.txt` liệt kê 16 tên file mong đợi. Khuyến nghị ảnh vuông ~600×600 px, dưới 100 KB; nếu lấy từ nguồn có giấy phép thì ghi tác giả/giấy phép vào `CREDITS.txt` cùng thư mục.
3. Hình nấm vẽ bằng code (`MushroomGlyph`), màu mũ ổn định theo tên loài: nhóm đỏ–cam–tím cho nấm độc, nhóm nâu–kem cho nấm ăn được.

Ảnh được giải mã ở chiều rộng ≤600 px để tiết kiệm bộ nhớ; ảnh mạng chỉ cache trong bộ nhớ, không cache đĩa.

## Kiểm tra

- [ ] Lọc “Nấm độc” chỉ còn loài có cờ độc; tìm theo tên khoa học không phân biệt hoa/thường.
- [ ] Tắt dịch vụ AI vẫn thấy 16 loài dự phòng; bật lại và làm mới thì số liệu theo server.
- [ ] Loài chưa có ảnh hiện hình nấm vẽ, không ô vỡ; thêm file đúng tên vào `assets/mushrooms` thì ảnh xuất hiện.
- [ ] Huy hiệu và khối kết luận luôn có chữ đi kèm màu; chế độ tối vẫn đọc được.
