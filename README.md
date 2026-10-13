# Quản lý & Nhận diện Nấm

Giao diện trên main đã chứa PR #4 (085febc), gồm thanh điều hướng Từ điển, Lịch sử, Quét, Quản lý và Cài đặt. lib/main.dart chạy lib/app/app.dart.

## Chạy với backend thật

Bật database và Redis theo cấu hình backend, rồi chạy API và classifier theo hướng dẫn có sẵn trong [RUN_BACKEND.md](../dacs_mushroom_backend/RUN_BACKEND.md). Flutter chỉ gọi Node cổng 8080; Node xử lý hàng đợi và gọi classifier nội bộ. Không cần seed lại database.

Trong thư mục Flutter:

~~~powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
~~~

Android Emulator mặc định dùng http://10.0.2.2:8080. Desktop/web dùng http://127.0.0.1:8080; điện thoại thật dùng IP LAN của máy backend. Có thể đổi URL trong **Cài đặt → Máy chủ quản lý và nhận diện**. Cấu hình debug Android cho phép HTTP; triển khai release nên dùng HTTPS.

Tài khoản demo backend đã seed mặc định: demo_admin, demo_manager, demo_staff / Demo@12345. Dùng thông tin thực tế nếu đã đổi mật khẩu.

## Dữ liệu mẫu khi không có backend

Backend mới cần schema `must_change_password` và bảng bộ đếm mã lô. Với database đang dùng, chạy migration `sql/account_password_batch_codes.sql` một lần theo RUN_BACKEND.md, sinh lại Prisma client và khởi động lại API trước khi chạy frontend mới. Mã lô được cấp tự động theo cơ sở/năm bắt đầu; mã cũ và QR được giữ nguyên.

Mở **Cài đặt → Dùng dữ liệu mẫu**. App mới cài mặc định dùng API thật; lựa chọn mock được lưu lại. Đổi chế độ sẽ đăng xuất để tách phiên mẫu khỏi phiên thật.

Tài khoản mẫu: admin/admin123, manager/manager123, staff/staff123. Các màn quản lý dùng dữ liệu trong bộ nhớ; thay đổi mẫu không gửi lên backend và không được giữ sau khi khởi động lại. Kết quả nhận diện trong chế độ mẫu ghi rõ là minh họa, ảnh chưa được AI phân tích.

Từ điển và chi tiết giống nấm dùng API công khai /mushroom-species, không cần đăng nhập và không gửi token. Ảnh lấy từ coverImageUrl/imageUrl trên backend, dự phòng ảnh đóng gói. Chế độ mẫu cũng hỗ trợ danh mục và gallery công khai.

## Kiểm thử

~~~powershell
# Toàn bộ kiểm thử giao diện, client API và chế độ mock.
.\tool\test_api.ps1 -All

# Thêm kiểm thử backend thật: đọc dữ liệu, CRUD bản ghi thử,
# phân quyền, báo cáo/xuất file và nhận diện qua multipart + Socket.IO.
.\tool\test_api.ps1 -All -Live

flutter build apk --debug --no-pub
~~~

Script kiểm thử dùng ánh xạ ổ đĩa tạm để tránh lỗi Flutter khi đường dẫn Windows có dấu nháy đơn. Test live dùng tài khoản admin demo, dọn bản ghi quản lý tạm sau khi chạy; lượt nhận diện thử và audit được backend lưu theo hành vi bình thường.

Có thể chạy test/api_live_test.dart với --dart-define=LIVE_API_TEST=true cùng LIVE_API_URL, LIVE_API_USERNAME, LIVE_API_PASSWORD để dùng máy chủ/tài khoản khác. Backend cần có API /cultivation-batches/by-code/{batchCode} và gallery isPublic theo hợp đồng hiện tại.

## Gallery và QR lô

Admin/manager có thể chọn Công khai khi tải/sửa ảnh. Upload giống nấm bật sẵn public, cơ sở/lô tắt sẵn. Khách chỉ xem ảnh public; ảnh private được tải bằng Bearer token đúng server và bỏ khỏi màn hình khi đăng xuất/đổi server.

Chi tiết lô có Mã QR và Lưu PNG. QR chứa mã lô, không phải ID/token/URL. Tra cứu tiến trình lô có nút Quét QR không cần đăng nhập. Quản lý và danh sách lô có Quét lô để cập nhật, resolve ID bằng API by-code rồi chọn Sinh trưởng/Chăm sóc/Thu hoạch. Quét chỉ mở form; người dùng kiểm tra và tự lưu.

Camera hỗ trợ Android/iOS/Web. Web cần HTTPS hoặc localhost, cấp quyền camera; desktop và khi camera lỗi vẫn nhập mã thủ công. Thư viện lưu PNG dùng file_saver 0.4.0 tương thích Dart 3.11.4 của dự án.

Các lệnh sau tự ánh xạ ổ đĩa tạm để tránh dấu nháy đơn trong đường dẫn Windows:

~~~powershell
.\tool\check_frontend.ps1 -Task analyze
.\tool\check_frontend.ps1 -Task test
.\tool\check_frontend.ps1 -Task android
.\tool\check_frontend.ps1 -Task web
~~~

APK debug: build/app/outputs/flutter-apk/app-debug.apk. Web: build/web. iOS build và kiểm tra camera iOS cần máy macOS/iPhone.


## Android native camera test

Run on a local Android test device after granting com.example.thu camera permission:

~~~powershell
adb -s emulator-5554 shell pm grant com.example.thu android.permission.CAMERA
.\tool\check_frontend.ps1 -Task camera -Device emulator-5554
~~~

This test starts the native camera and decodes the actual PNG exported by the QR dialog, including Unicode and URL-special characters. It does not call business APIs. The integration test replaces the debug APK entrypoint; rebuild/install the normal debug APK with check_frontend.ps1 -Task android afterward.


## Phân quyền lô, ảnh chăm sóc và thông báo

Xem [STAFF_WORKFLOW.md](STAFF_WORKFLOW.md) để cấu hình backend, Firebase/FCM cho Android và iOS và giao thức refresh mới. Staff cần được admin thêm vào cơ sở và phân công từng lô trước khi thao tác. Push mặc định tắt cho tới khi có cấu hình Firebase/APNs.

Ba chế độ VPS / Mạng nội bộ / VS Code tunnel, cấu hình Firebase và đăng ký thiết bị: xem [PUSH_HOSTING.md](PUSH_HOSTING.md).

Application ID/bundle ID hiện tại: `com.loql.layla.themushroomapp`. Đăng ký Android và iOS trong Firebase với đúng ID này; xem PUSH_HOSTING.md.
