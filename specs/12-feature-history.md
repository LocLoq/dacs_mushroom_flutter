# 12 — Feature: Recognition History

## 1. Tổng quan
- **Mục tiêu:** Lưu trữ bền vững toàn bộ các lần quét và kết quả nhận diện nấm trên thiết bị, cho phép người dùng xem lại offline mà không phụ thuộc vào kết nối mạng backend.
- **Tập tin liên quan:**
  - `lib/features/recognition_history/presentation/recognition_history_screen.dart`
  - `lib/features/recognition_history/presentation/widgets/history_detail_dialog.dart`
  - `lib/features/recognition_history/data/history_item.dart`
  - `lib/core/services/recognition_history_service.dart`

## 2. Quy tắc lưu trữ
- **Vị trí lưu:**
  - JSON metadata lưu trong `SharedPreferences` (key `recognition_history_v1`).
  - File hình ảnh thu nhỏ preview (`preview_<jobId>.jpg`) và file media gốc (`source_<jobId>.<ext>`) được lưu trữ tại `<AppDocumentsDirectory>/recognition_history/media/`.
- **Dung lượng & Giới hạn:**
  - Tối đa **200 mục** (`_kMaxHistoryItems = 200`).
  - Khi thêm mục mới vượt quá 200, các mục cũ nhất ở cuối danh sách sẽ tự động bị cắt bỏ.
- **Cơ chế Upsert (`upsertFromJob`):**
  - Nếu `jobId` đã tồn tại trong danh sách: Cập nhật trạng thái mới nhất và kết quả (khi job chuyển từ `processing` sang `completed`).
  - Nếu `jobId` chưa có: Thêm vào vị trí đầu tiên của danh sách (sắp xếp giảm dần theo thời gian).

## 3. Giao diện `RecognitionHistoryScreen`
1. **Thanh tiêu đề:** Nút làm mới, hiển thị tổng số lượt quét đã lưu.
2. **Danh sách bản ghi:**
   - Ảnh xem trước thu nhỏ từ bộ nhớ máy (`File(previewImagePath)`). Kiểm tra an toàn `File.existsSync()` trước khi hiển thị; nếu file đã bị dọn rác, hiển thị icon thay thế.
   - Tên nấm, nhãn dự đoán, thời điểm quét (định dạng ngày giờ).
   - Chip phân loại độc tính (Đỏ: Nấm độc, Xanh: Nấm an toàn, Cam: Không xác định).
   - Badge trạng thái job (`completed`, `processing`, `failed`).
3. **Chi tiết bản ghi (`HistoryDetailDialog`):**
   - Chạm vào một bản ghi bất kỳ sẽ mở modal hiển thị ảnh phóng to và toàn bộ widget `ResultPayloadView` (độ tin cậy, lý do quyết định, thời gian suy luận...).

