# 10 — Feature: AI Mushroom Recognition

## 1. Tổng quan
- **Mục tiêu:** Cho phép người dùng (công khai, không cần đăng nhập) nhận diện nấm ăn được hoặc nấm độc thông qua:
  - Chọn ảnh từ thư viện (`ImageSource.gallery`).
  - Chụp ảnh trực tiếp từ máy ảnh (`ImageSource.camera`).
  - Quay video trực tiếp (`ImageSource.camera`), áp dụng thuật toán Computer Vision client-side để tự động trích xuất frame có chất lượng cao nhất (độ sắc nét và độ phơi sáng).
- **Tập tin liên quan:**
  - `lib/features/recognition/presentation/mushroom_recognition_screen.dart`
  - `lib/features/recognition/presentation/widgets/job_result_card.dart`
  - `lib/features/recognition/presentation/widgets/result_payload_view.dart`
  - `lib/features/recognition/presentation/widgets/result_row.dart`
  - `lib/features/recognition/presentation/widgets/result_popup_dialog.dart`
  - `lib/features/recognition/data/job_status.dart`
  - `lib/features/recognition/data/prepared_frame.dart`
  - `lib/features/recognition/data/queue_job.dart`
  - `lib/features/recognition/data/queue_event.dart`
  - `lib/core/services/frame_selector_service.dart`
  - `lib/core/services/backend_queue_service.dart`

## 2. Quyền truy cập
- **Công khai:** Người dùng không cần tài khoản hoặc đăng nhập vẫn có thể sử dụng toàn bộ tính năng nhận diện này.

## 3. Các khối giao diện chính trên `MushroomRecognitionScreen`
1. **Header trạng thái kết nối:**
   - Hiển thị URL backend hiện tại (`http://...`).
   - Badge trạng thái WebSocket: Xanh (Đã kết nối), Đỏ (Mất kết nối / Đang ngắt), Vàng (Đang kết nối lại...).
   - Nút lối tắt: Mở màn hình `Lịch sử nhận diện` và `Cài đặt`.
2. **Bộ chọn phương tiện (Media Selector):**
   - 3 nút bấm lớn: *Tải ảnh lên*, *Chụp ảnh*, *Quay video*.
   - Thanh tiến trình tải khi đang xử lý trích xuất frame từ video (`_isPreparing`).
3. **Khung xem trước & Đánh giá chất lượng (`PreparedFrame`):**
   - Hiển thị ảnh xem trước bo góc viền (`ClipRRect`).
   - Tag nguồn ảnh (Ảnh tĩnh hoặc Video kèm mốc thời gian frame `ms`).
   - Dung lượng ảnh.
   - Điểm chất lượng hình ảnh được chấm tự động ($0.0 - 100.0\%$).
   - Nút bấm: *"Upload ảnh và tạo job"*.
4. **Danh sách hàng đợi công việc (Job Queue):**
   - Hiển thị các job đang chờ hoặc vừa hoàn tất trong phiên làm việc.
   - Hiển thị widget `JobResultCard`: Badge trạng thái (`queued`, `processing`, `completed`, `failed`), thời gian cập nhật, ảnh thu nhỏ.
   - Khi hoàn thành: Nhúng trực tiếp widget `ResultPayloadView`.
5. **Nhật ký sự kiện thời gian thực (Event Log):**
   - Hiển thị tối đa 10 sự kiện gần nhất nhận được từ WebSocket dạng font Monospace.

## 4. Cơ chế Popup hiển thị kết quả (Anti-Spam Dialog)
- Khi một job chuyển sang `completed` hoặc `failed`:
  - Kiểm tra `_popupEligibleJobIds`: Chỉ các job được tạo trong chính phiên màn hình này mới đủ điều kiện hiển thị dialog.
  - Kiểm tra `_shownResultDialogJobs`: Tránh trường hợp Polling và WebSocket cùng kích hoạt mở popup trùng lặp.
  - Mở `ResultPopupDialog` với đầy đủ cảnh báo an toàn sinh học.

## 5. Cấu trúc Widget hiển thị kết quả (`ResultPayloadView`)
- **Tên nấm:** Tên tiếng Việt / thông dụng hoặc tên khoa học, hiển thị "Không xác định" nếu nhãn là `unknown`.
- **Cảnh báo độc tính:**
  - Nấm an toàn: Màu xanh lá cây.
  - Nấm độc: Màu đỏ cảnh báo.
  - Không xác định: Màu cam cảnh báo.
- **Độ tin cậy:** Định dạng phần trăm chính xác 2 chữ số (ví dụ: `94.52%`).
- **Bảng chi tiết kỹ thuật (`ResultRow`):** Nhãn dự đoán gốc (`raw_prediction`), Đạt ngưỡng chấp nhận (`accepted_prediction`), Ngưỡng tin cậy (`confidence_threshold`), Lý do quyết định (`decision_reason`), Kích thước ảnh, Thời gian suy luận (`inference_time_seconds`).

