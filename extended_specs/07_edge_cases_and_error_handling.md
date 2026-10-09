# 07 - Edge Cases & Error Handling Specification

Tài liệu này đặc tả ma trận các tình huống ngoại lệ (Edge Cases), lỗi hệ thống và chiến lược tự phục hồi (Self-healing & Resilience) được thiết kế trong ứng dụng **app_mushroom**.

---

## 1. Ma trận lỗi mạng và kết nối Backend

| Tình huống ngoại lệ | Triệu chứng | Cơ chế xử lý trong mã nguồn | Phản hồi giao diện người dùng |
| :--- | :--- | :--- | :--- |
| **URL nhập vào không đúng định dạng** | Người dùng nhập chuỗi không hợp lệ (ví dụ: `abc`, `ftp://...`) | `BackendQueueService.normalizeBaseUrl` ném `FormatException` | Bắt lỗi tại `_saveBackendBaseUrl`, hiển thị thông báo lỗi màu đỏ trên dialog/màn hình cài đặt |
| **Server Backend chưa bật hoặc sai IP** | Kết nối WebSocket và HTTP không thể thiết lập | `reconnectWithTimeout` áp dụng timeout 15 giây. Khi quá hạn, ném `TimeoutException` | Dialog/SnackBar hiển thị: *"Không thể kết nối backend trong 15 giây: ..."* |
| **Mạng chập chờn, WebSocket rớt giữa chừng** | Sự kiện `onDone` hoặc `onError` của WebSocket kích hoạt | Hàm `_handleWsMessage` bắt lỗi, set `_wsConnected = false`, phát `ws.closed` và kích hoạt `_scheduleReconnect(2s)` | Chip trạng thái trên MainMenu và RecognitionPage chuyển sang màu đỏ: *"WS đang ngắt"*. Hệ thống tự thử kết nối lại sau mỗi 2 giây |
| **WebSocket mất nhưng HTTP vẫn hoạt động** | Server không gửi được realtime event | **Cơ chế Fallback Polling:** Timer `_pollTimer` (chạy mỗi 2s) quét các job đang `queued` hoặc `processing` để gọi `GET /api/jobs/{id}` | Kết quả của người dùng vẫn được cập nhật bình thường nhờ cơ chế đồng bộ kép (Dual-Sync) |
| **Gửi Ping khi socket đã đóng** | Người dùng bấm nút Ping trong Settings hoặc socket chết bất ngờ | Khối `try/catch` bắt `StateError`, set `_wsConnected = false`, phát `ws.error` và gọi `_scheduleReconnect()` | Hiển thị log sự kiện `ws.error: WebSocket đã đóng` |

---

## 2. Xử lý ngoại lệ trong Hàng đợi Job (Job Queue Resilience)

### 2.1. Lỗi HTTP 404 khi truy vấn Job (`fetchJob`)
- **Nguyên nhân:** Job ID không tồn tại trên RAM của server (do server vừa khởi động lại hoặc ID sai).
- **Cách xử lý:**
  ```dart
  if (response.statusCode == 404) {
    _upsertJob(
      jobId: jobId,
      status: JobStatus.failed,
      error: 'Job không tồn tại (404)',
    );
    _emit('job.status', {'job_id': jobId, 'status': 'failed'});
    _emit('job.result', {
      'job_id': jobId,
      'status': 'failed',
      'error': 'Job không tồn tại (404)',
    });
    return;
  }
  ```
- **Kết quả:** Job được cập nhật ngay sang màu đỏ (`failed`), dừng polling đối với job này để tránh spam request 404 lên server.

### 2.2. Kiểm soát hiển thị Popup kết quả (Anti-spam Dialog)
- Để tránh việc kết quả hiển thị hộp thoại liên tục mỗi khi polling hoặc nhận sự kiện WS lặp:
  1. `_shownResultDialogJobs`: Bộ `Set<String>` lưu trữ các Job ID đã từng bật popup hiển thị kết quả. Nếu ID đã có trong Set, bỏ qua không mở popup nữa.
  2. `_popupEligibleJobIds`: Bộ `Set<String>` chỉ cho phép các job được người dùng bấm tạo **trong chính phiên màn hình hiện tại** được quyền bật popup. Các job cũ trong lịch sử hoặc job từ phiên trước sẽ không gây bật popup phiền toái khi app khởi động.

---

## 3. Xử lý ngoại lệ xử lý Media & Hình ảnh

### 3.1. Người dùng hủy chọn ảnh / video
- Khi hộp thoại chọn ảnh của hệ điều hành đóng lại mà người dùng không chọn gì:
  - `file == null`
  - Đặt cờ `_isPreparing = false` và `return` ngay lập tức, không báo lỗi.

### 3.2. File ảnh bị hỏng hoặc dung lượng 0 byte
- Trong `_scoreFrameQuality`:
  - `img.decodeImage(bytes)` trả về `null`.
  - Hàm an toàn trả về điểm chất lượng `0.0`, không gây ngoại lệ Crash ứng dụng.
- Nếu ảnh có kích thước quá nhỏ ($< 3 \times 3\text{ px}$):
  - Trả về điểm `0.0`.

### 3.3. Video không có khung hình hợp lệ hoặc bị lỗi thời lượng
- Nếu video có thời lượng $\le 0\text{ ms}$: Hàm `_buildSamplePoints` tự động fallback về mốc `[0]`.
- Nếu toàn bộ 8 mốc lấy mẫu đều không trích xuất được thumbnail:
  - Ném ngoại lệ `Exception('Không lấy được frame hợp lệ từ video.')`.
  - Khối `catch` trên UI bắt lỗi, tắt loading và hiển thị thông báo lỗi thân thiện trên giao diện: *"Không thể chuẩn bị dữ liệu ảnh: ..."*.

---

## 4. Xử lý ngoại lệ mô hình AI và nhãn suy luận

### 4.1. Nhãn không xác định (`prediction: "unknown"`)
- Khi backend không thể nhận diện được loài nấm:
  - Trường `prediction` có giá trị `"unknown"`.
  - UI tự động chuyển đổi sang chuỗi bản địa hóa: *"Không xác định"* / *"Unknown"*.
  - Chip hiển thị chuyển sang màu cam cảnh báo thay vì màu đỏ nấm độc hay màu xanh nấm lành.

### 4.2. Độ tin cậy thấp (`accepted_prediction: false`)
- Mô hình nhận diện có thể ra một loài nấm nhưng điểm tin cậy `confidence` dưới ngưỡng `confidence_threshold`.
- Server trả về `accepted_prediction: false` kèm `decision_reason` (ví dụ: *"Confidence 0.42 below threshold 0.70"*).
- UI hiển thị rõ ràng cả hai trường này để người dùng hiểu lý do hệ thống không khuyến nghị kết quả đó.

### 4.3. Ép kiểu dữ liệu an toàn (Safe Type Casting)
Trong `_ResultPayloadView` và `RecognitionHistoryItem`, toàn bộ dữ liệu từ JSON được phân tích qua các hàm chuyển đổi an toàn:
- `_toBool(dynamic)`: Nhận diện linh hoạt cả `bool`, `num` ($1/0$), và `String` (`"true"`, `"false"`, `"1"`, `"0"`).
- `_toDouble(dynamic)`: Nhận diện cả `num` và `String` có thể parse.
- `_asString(dynamic)`: Xử lý `null`, loại bỏ khoảng trắng thừa, chuyển chuỗi rỗng thành `null`.
- `_formatPercent(dynamic)`: Tự động phát hiện giá trị thập phân $\le 1.0$ (ví dụ `0.95` thành `95.00%`) hoặc giá trị đã nhân sẵn $100$.

---

## 5. Xử lý ngoại lệ lưu trữ và hệ thống file

### 5.1. Dữ liệu SharedPreferences bị lỗi định dạng
- Khi file JSON lưu lịch sử nhận diện bị lỗi cú pháp:
  - Hàm `_loadItemsFromPrefs` được bao bọc trong `try / catch (_)`.
  - Nếu xảy ra lỗi phân tích, an toàn trả về danh sách rỗng `const []`, không làm sập ứng dụng khi khởi động.

### 5.2. File phương tiện bị người dùng hoặc hệ điều hành dọn rác
- Trước khi hiển thị ảnh từ file trong `RecognitionHistoryPage`:
  - Luôn kiểm tra: `item.previewImagePath != null && File(item.previewImagePath!).existsSync()`.
  - Nếu file không còn tồn tại trên đĩa: Hiển thị icon placeholder `Icons.image_not_supported_outlined` thay vì gây lỗi render ảnh.

