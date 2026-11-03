# S11 — Lịch sử nhận diện

**Vị trí:** tab **Lịch sử** → nhánh “Máy chủ”. Chỉ manager/admin thấy bộ chuyển “Trên máy này / Máy chủ”; staff và khách chỉ có “Trên máy này”. **Quyền (nhánh Máy chủ):** manager/admin.

## Giao diện và hành vi

List 20/trang; search tên dự đoán, status, từ ngày/đến ngày. Chỉ dùng card, gồm tên file, dự đoán, trạng thái, độ tin cậy và thời điểm. Status `QUEUED,PROCESSING,SUCCEEDED,FAILED`.

Nhấp mở dialog tối đa 620 px, cao 80% màn hình; GET detail riêng, hiển thị tên file/thời điểm/trạng thái/kết quả hoặc lỗi. **Ảnh đầu vào không được lưu**, không có thumbnail ảnh gốc từ API. Không có sửa/xóa. Đóng dialog giữ page/filter/scroll, retry chỉ tải lại detail.

## Nhánh “Trên máy này”

Dành cho mọi người, không gọi API Trại nấm. Mỗi lượt quét hoàn tất hoặc thất bại ở tab Quét ([S10](S10_CLASSIFIER.md)) được lưu trên thiết bị (`RecognitionHistoryService`) cùng ảnh xem trước. Danh sách card: ảnh 64 px, tên loài, chip trạng thái (Nấm độc/An toàn/Thất bại), độ tin cậy, thời gian. Vuốt sang trái để xóa một mục, nút thùng rác xóa tất cả (có xác nhận). Nhấn mở hộp thoại chi tiết: ảnh đầu, khối kết luận, thông số kỹ thuật gập gọn và khung lưu ý an toàn. Kết quả giả lập ([S10](S10_CLASSIFIER.md)) hiển thị nhãn “KẾT QUẢ GIẢ LẬP” cả ở đây.

## API call

| Method / path | Query / response |
| --- | --- |
| GET /api/mushroom-classifier/history | `page=1&limit=20&predictedName=...&status=...&from=...&to=...` → 200 data/pagination |
| GET /api/mushroom-classifier/history/{id} | UUID → 200 data detail |

Chỉ gửi filter có giá trị. Search UI dùng **predictedName**, không search. Backend tối đa 100/trang. Ngày lọc là ISO UTC đổi từ đầu/cuối ngày local thiết bị; from ≤ to.

Row: `id,originalName,mimeType,fileSize,status,predictedName,edibility,confidence,errorMessage,queuedAt,startedAt,completedAt,createdAt,updatedAt,user`; timestamps/kết quả có thể null. User nếu có: `{id,username,full_name}`. Detail bổ sung `result`; không giả định `imageUrl`.

Ví dụ `GET /api/mushroom-classifier/history?page=1&limit=20&status=SUCCEEDED&from=2026-10-04T17%3A00%3A00.000Z&to=2026-10-05T16%3A59%3A59.999Z`.

Độ tin cậy 0–1 hiển thị %, null là chưa có dữ liệu. Lỗi detail không xóa list. 401/403 theo contract chung.

## Kiểm tra

- [ ] Query đúng predictedName/status/ISO, filter reset page 1.
- [ ] Staff không gọi history API.
- [ ] Detail gọi UUID đúng; queued/failed/null không dựng kết quả giả.
- [ ] Không đòi endpoint ảnh gốc, sửa hoặc xóa.
