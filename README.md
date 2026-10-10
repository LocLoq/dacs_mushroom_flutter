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

Mở **Cài đặt → Dùng dữ liệu mẫu**. App mới cài mặc định dùng API thật; lựa chọn mock được lưu lại. Đổi chế độ sẽ đăng xuất để tách phiên mẫu khỏi phiên thật.

Tài khoản mẫu: admin/admin123, manager/manager123, staff/staff123. Các màn quản lý dùng dữ liệu trong bộ nhớ; thay đổi mẫu không gửi lên backend và không được giữ sau khi khởi động lại. Kết quả nhận diện trong chế độ mẫu ghi rõ là minh họa, ảnh chưa được AI phân tích.

Danh mục thật nằm ở API bảo vệ /mushroom-species, nên cần đăng nhập khi dùng backend thật. Chế độ mẫu cho phép xem danh mục offline.

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

Có thể chạy test/api_live_test.dart với --dart-define=LIVE_API_TEST=true cùng LIVE_API_URL, LIVE_API_USERNAME, LIVE_API_PASSWORD để dùng máy chủ/tài khoản khác. Các thay đổi tích hợp chỉ ở repository Flutter; không sửa mã hoặc cấu hình backend.
