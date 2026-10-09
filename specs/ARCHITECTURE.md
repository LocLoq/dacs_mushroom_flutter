# Kiến trúc ứng dụng

Mô tả cấu trúc mã của app Flutter `dacs_mushroom_flutter` (package `thu`). Hành vi từng màn nằm ở [UI_DESIGN_SPEC](UI_DESIGN_SPEC.md) và các S01–S21; contract API ở [API_CONTRACT](API_CONTRACT.md).

## 1. Công nghệ

Flutter, Dart `>=3.11.4`, Material 3. Gói chính: `http` + `http_parser` (REST, multipart), `web_socket_channel` (hàng đợi nhận diện), `shared_preferences` (cài đặt, token), `image_picker`, `video_player` + `video_thumbnail` + `image` (chọn khung hình từ video), `path_provider` (lưu file báo cáo). Font Be Vietnam Pro đóng gói trong `assets/fonts`.

## 2. Hai nguồn dữ liệu độc lập

```
                       ┌─ ApiClient ─────────────► dịch vụ AI (FastAPI): catalog
 Tab Quét / Từ điển ───┼─ BackendQueueService ───► upload ảnh, GET job, WebSocket /ws/queue
                       └─ RecognitionHistoryService ► lịch sử lưu trên máy

                       ┌─ chế độ mẫu BẬT ─► MockBackend (trong bộ nhớ)
 Tab Quản lý, Lịch sử ─┤
 (nhánh Máy chủ)       └─ chế độ mẫu TẮT ─► HTTP tới API Trại nấm (Node) qua FarmApi
```

- **Dịch vụ AI** (`ApiClient`, `BackendQueueService`): địa chỉ riêng ở Cài đặt, mặc định `http://10.0.2.2:8000`. Xem [S10](S10_CLASSIFIER.md), [S20](S20_AI_CATALOG.md).
- **API Trại nấm** (`FarmApi`): địa chỉ `ApiConfig`, mặc định `http://10.0.2.2:8080/api`; gắn Bearer token từ `LocalSession`; chuẩn hóa lỗi thành `ApiException`; 401/403 `AUTH_INVALID_TOKEN` xóa phiên. Mọi màn chỉ gọi qua `FarmApi`, nên đổi giữa dữ liệu mẫu và API thật không đụng tới màn hình. Xem [MOCK_DATA](MOCK_DATA.md).

## 3. Cấu trúc `lib/`

| Thư mục | Vai trò |
| --- | --- |
| `main.dart`, `app/` | Khởi động, `MushroomApp` (theme sáng/tối, ngôn ngữ, khôi phục phiên nền), `HomeScreen` (5 tab, thanh dưới/thanh bên) |
| `app/theme/` | `AppColors`, `AppTheme` (Material 3, font, bo góc) |
| `core/network/` | `FarmApi`, `ApiConfig`, `ApiClient` (AI), `MockConfig`, `MockBackend`, `MockSeed` |
| `core/storage/` | `LocalSession`: token, hồ sơ, trạng thái guest/pending/signedIn, `changes` để UI lắng nghe |
| `core/services/` | Hàng đợi nhận diện, chọn khung hình video, lịch sử trên máy, lưu cài đặt |
| `core/utils/` | `format.dart` (tiền VND từ chuỗi Decimal, ngày giờ, nhãn enum, màu trạng thái), `json_utils.dart` (`J`, `PageData`), `image_rules.dart` |
| `core/widgets/` | `PagedListView`, `showFormSheet`/`FieldDef`, `FutureBody`/`ErrorView`/`EmptyView`, `NetImage`, `SoftCard`, `StatusChip`, `InfoRow`, `MushroomGlyph`, `MushroomPhoto`… |
| `core/localization/` | `AppTextScope` + `tr()` (VI/EN) cho các màn có hỗ trợ |
| `features/<tên>/` | Mỗi chức năng một thư mục: `batches`, `tasks`, `dashboard`, `reports`, `audit`, `users`, `species`, `facilities`, `gallery`, `public_growth`, `server_history`, `manage`, `auth`, `settings`, `recognition`, `recognition_history`, `mushroom_catalog` |

Model của khu Quản lý là `Map<String, dynamic>` (`typedef J`) đọc qua extension `s/sn/i/d/m/l`, vì contract có nhiều field tuỳ chọn; riêng nhận diện/catalog/lịch sử có class model.

## 4. Quy ước đáng nhớ

- **Phiên:** `LocalSession.status` ∈ guest/pending/signedIn. Chỉ signedIn khi `GET /auth/me` trả id dương, username và role hợp lệ. Tab Quản lý lắng nghe `LocalSession.changes`.
- **Điều hướng:** 5 tab giữ trạng thái (`IndexedStack`), màn con dùng `Navigator.push`; không có URL route/deep link.
- **Danh sách:** luôn qua `PagedListView` (search khi Enter, bỏ kết quả cũ đến muộn). **Form:** luôn qua `showFormSheet` (allowlist field, Decimal giữ dạng chuỗi, lỗi giữ dữ liệu nhập).
- **Tiền** không bao giờ đi qua `double` ở giao diện (chỉ `vnd()` định dạng chuỗi); riêng `MockBackend` tự tính bằng số thực.
- Quyền chỉ để **ẩn/hiện** giao diện; server mới là nơi cưỡng chế.

## 5. Kiểm thử và mức xác minh

- `test/mock_backend_test.dart` (7 test) và `test/widget_test.dart` (khởi động app). **Chưa được chạy.**
- Đã kiểm tra tĩnh bằng parser: cú pháp 73 file Dart, import tồn tại, tên dùng đã import. **Chưa chạy `flutter analyze`, `flutter test`, chưa chạy trên thiết bị hay giả lập.**

## 6. Nên làm trước khi phát hành

1. `flutter pub get`, `flutter analyze`, `flutter test`; chạy thử 3 vai trò ở chế độ mẫu.
2. Tắt mặc định chế độ dữ liệu mẫu và **xóa nhánh giả lập kết quả nhận diện** ở `BackendQueueService` ([S10](S10_CLASSIFIER.md) §3).
3. Chuyển token sang secure storage; bổ sung mở/chia sẻ file báo cáo ([S13](S13_REPORT_EXPORT.md)).
4. Dịch các màn khu Quản lý sang tiếng Anh nếu cần; thêm ảnh thật cho `assets/mushrooms/`.
