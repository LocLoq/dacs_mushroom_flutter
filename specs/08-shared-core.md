# 08 — Shared Core (`app/theme`, `app/config`, `core/*`)

## Theme
- `lib/app/theme/app_colors.dart` — `AppColors`: static `const Color` fields (`primary`, `primaryDark`, `background`, `card`, `textPrimary`, `textSecondary`, `danger`, `warning`, `success`). Bổ sung màu xanh rêu thực vật (`#4F772D` / `#2D6A4F`) và màu dark theme (`#90A955`).
- `lib/app/theme/app_theme.dart` — Cung cấp cả `AppTheme.light()` và `AppTheme.dark()`, `useMaterial3: true`, card bo tròn `borderRadius: 18`, input bo tròn `borderRadius: 14`.

## Localization (`lib/core/localization/`)
- `app_language.dart`: Enum `AppLanguage { vi, en }`.
- `app_text_scope.dart`: `AppTextScope` kế thừa `InheritedWidget`, cung cấp hàm helper:
  ```dart
  String tr(BuildContext context, {required String vi, required String en})
  ```
  Cho phép chuyển đổi ngôn ngữ thời gian thực trên toàn bộ ứng dụng mà không cần khởi động lại.

## Dịch vụ Lõi (`lib/core/services/`)

### 1. `FrameSelectorService` (`lib/core/services/frame_selector_service.dart`)
- **Mục đích:** Xử lý và đánh giá chất lượng ảnh tĩnh hoặc video trên máy client.
- **Phương thức:**
  - `prepareFromImage(File file)`: Đọc mảng byte, tính điểm chất lượng qua `_scoreFrameQuality`.
  - `prepareFromVideo(File file)`: Sử dụng `VideoPlayerController` đo thời lượng, sinh 8 mốc thời gian mẫu dọc theo timeline video (tránh khung đen ở đầu/cuối), trích xuất ảnh thu nhỏ bằng `video_thumbnail` (JPEG quality 95, maxWidth 720), tính điểm từng frame và chọn ra frame có điểm số cao nhất.
- **Công thức chấm điểm (`_scoreFrameQuality`):**
  - Giảm kích thước về chiều rộng 320px để tính toán thời gian thực không gây lag UI.
  - Chuyển ảnh xám chuẩn Rec. 601 Luma: $\text{Lum} = 0.299R + 0.587G + 0.114B$.
  - Tính năng lượng Gradient 2 chiều (đo độ sắc nét / chống mờ nhòe do rung tay): $\text{SharpnessScore} = \text{clamp}(\overline{\text{Gradient}} / 60, 0.0, 1.0)$.
  - Tính độ phơi sáng: $\text{ExposureScore} = \text{clamp}(1.0 - |\overline{\text{Lum}} - 128| / 128, 0.0, 1.0)$.
  - Điểm tổng hợp: $\text{QualityScore} = 0.8 \times \text{SharpnessScore} + 0.2 \times \text{ExposureScore}$.

### 2. `BackendQueueService` (`lib/core/services/backend_queue_service.dart`)
- **Mục đích:** Quản lý giao tiếp mạng HTTP & WebSocket với server.
- **Tính năng:**
  - Chuẩn hóa URL (`normalizeBaseUrl`): Bắt buộc scheme `http`/`https`, loại bỏ path thừa.
  - Quản lý kênh WebSocket `/ws/queue`: Auto-reconnect sau 2 giây khi rớt kết nối; timeout 15 giây khi kiểm tra kết nối lần đầu (`reconnectWithTimeout`).
  - Ping-Pong heartbeat: Client gửi `"ping"`, server trả về `"pong"`.
  - Cơ chế Dual-Sync: Lắng nghe sự kiện WebSocket (`job.status`, `job.result`) song song với Timer polling 2s (`GET /api/jobs/{id}`) cho các job đang xử lý.
  - Gửi ảnh qua `http.MultipartRequest('POST', '/api/images/upload')`.
  - Hỗ trợ chế độ offline simulation (giả lập kết quả nhận diện sau 2s khi không có backend) để kiểm thử và demo.

### 3. `RecognitionHistoryService` (`lib/core/services/recognition_history_service.dart`)
- **Mục đích:** Lưu trữ bền vững (Offline-first) toàn bộ kết quả nhận diện trên thiết bị.
- **Quy tắc:**
  - Lưu mảng JSON trong `SharedPreferences` dưới key `recognition_history_v1`.
  - Giới hạn tối đa 200 bản ghi (tự động cắt bỏ các bản ghi cũ nhất khi vượt quá).
  - Tự động sao lưu ảnh thu nhỏ preview (`preview_<jobId>.jpg`) và file gốc (`source_<jobId>.<ext>`) vào thư mục `<AppDocumentsDirectory>/recognition_history/media/`.
  - Xử lý tên file an toàn (`_safeName`) thay thế ký tự lạ bằng `_`.

### 4. `AppPreferencesService` (`lib/core/services/app_preferences_service.dart`)
- **Mục đích:** Đọc/ghi cấu hình ứng dụng qua `SharedPreferences`:
  - `backend_base_url`: URL server FastAPI.
  - `dark_mode`: Cờ giao diện tối (`bool`).
  - `language_code`: Mã ngôn ngữ (`'vi'` hoặc `'en'`).
  - `backend_configured`: Cờ đánh dấu đã qua bước thiết lập lần đầu.

## Config
- `lib/app/config/env_config.dart` — `EnvConfig.baseUrl`, `connectTimeout`, `receiveTimeout`.
- `lib/app/config/app_constants.dart` — `AppConstants.kDefaultBackendBaseUrl`, các key lưu trữ `SharedPreferences`.

## `lib/core/storage/local_session.dart` — `LocalSession`
```dart
class LocalSession {
  static String? _token;
  static Map<String, dynamic>? _user;
  static void save(String token, Map<String, dynamic> user);
  static bool get isLoggedIn => _token != null;
  static String get username => _user?['username'] ?? '';
  static String get role => _user?['role'] ?? '';
  static void clear();
}
```

## Shared widgets (`lib/core/widgets/`)
| File | Class | Notes |
|---|---|---|
| `custom_button.dart` | `CustomButton` | Wraps `ElevatedButton`. Props: `label`, `onPressed`, `loading`, optional `icon`. Height: 48. |
| `custom_textfield.dart` | `CustomTextField` | Wraps `TextField`. Props: `label`, `controller`, `obscure`, `keyboardType`, `suffixIcon`. |
| `status_chip.dart` | `StatusChip` | Pill-shaped label, `text` + `color`. |

