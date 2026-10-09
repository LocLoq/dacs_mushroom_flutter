# 13 — Feature: Settings & Connection Management

## 1. Tổng quan

- **Mục tiêu:** Quản trị cấu hình ứng dụng bao gồm URL backend, trạng thái kênh WebSocket, kiểm thử kết nối, chuyển đổi ngôn ngữ và giao diện Sáng / Tối.
- **Tập tin liên quan:**
  - `lib/features/settings/presentation/settings_screen.dart`
  - `lib/features/settings/presentation/first_run_backend_dialog.dart`
  - `lib/core/services/app_preferences_service.dart`
  - `lib/core/services/backend_queue_service.dart`

## 2. Các chức năng chính

### 2.1. Cấu hình Backend & WebSocket

- **Ô nhập URL:** Nhập địa chỉ máy chủ (mặc định Android emulator `http://10.0.2.2:8000`, thiết bị thật `http://<LAN-IP>:8000`).
- **Nút tác vụ:**
  - _Lưu URL_: Chỉ lưu vào SharedPreferences.
  - _Kết nối WS_: Lưu URL và kích hoạt kết nối WebSocket `/ws/queue` với timeout 15 giây.
  - _Ngắt WS_: Chủ động đóng kết nối WebSocket hiện tại.
  - _Ping_: Gửi gói tin `"ping"` để kiểm tra độ trễ và khả năng phản hồi của server.
- **Nhật ký sự kiện thời gian thực (Event Log):**
  - Hiển thị bảng cuộn chứa 20 sự kiện WebSocket gần nhất kèm mốc thời gian (ví dụ: `ws.connected`, `job.status`, `pong`).

### 2.2. Tùy chọn Giao diện & Ngôn ngữ

- **Chế độ tối (Dark Mode):** Công tắc chuyển đổi giao diện nền tối dựa trên `AppTheme.dark()`.
- **Ngôn ngữ:** Chuyển đổi giữa `Tiếng Việt` (`AppLanguage.vi`) và `English` (`AppLanguage.en`) thông qua `AppTextScope`.

### 2.3. Hộp thoại khởi tạo lần đầu (`FirstRunBackendDialog`)

- Tự động hiển thị khi mở app lần đầu nếu `backendConfigured == false`.
- Cho phép người dùng nhập IP máy chủ hoặc bấm _"Dùng thử chế độ Demo"_ để khám phá tính năng offline mà không bị chặn lại.

## Khởi tạo từ HomeScreen

Sau frame đầu tiên khi `HomeScreen` được khởi tạo, ứng dụng gọi:

`FirstRunBackendDialog.checkAndShow(context)`

Dialog này dùng để kiểm tra hoặc hướng dẫn cấu hình backend lần đầu.
