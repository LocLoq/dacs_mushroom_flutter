# Bộ đặc tả bàn giao ứng dụng Trại Nấm

**Phiên bản 2.1 · Đối chiếu ngày 05/10/2026, đồng bộ với giao diện Flutter mới ngày 08/10/2026.**

Bộ này mô tả giao diện, quyền và API đang được app Flutter sử dụng. Có thể sao chép toàn bộ thư mục `specs` để triển khai một ứng dụng khác dùng cùng backend; không cần các bản prototype hay tài liệu nằm ngoài thư mục.

## Cách sử dụng

1. Đọc [UI_DESIGN_SPEC.md](UI_DESIGN_SPEC.md) để dựng điều hướng, giao diện thích ứng và component chung.
2. Đọc [API_CONTRACT.md](API_CONTRACT.md) để triển khai transport, xác thực, phân trang, lỗi và kiểu dữ liệu.
3. Import [openapi.yaml](openapi.yaml) vào công cụ OpenAPI; đây là bản sao Swagger backend tại thời điểm đối chiếu.
4. Triển khai các màn S01–S21 theo mục lục trong UI_DESIGN_SPEC (kèm vị trí của từng màn trong 5 tab). Mỗi màn có API call, payload và tiêu chí kiểm tra.
5. Kiểm tra theo quyền admin/manager/staff, dữ liệu thật, 390/768/1440 px và cỡ chữ lớn.

Các ID và dữ liệu trong ví dụ chỉ minh họa; phải lấy ID hợp lệ từ server. API cơ sở trong ví dụ là `http://127.0.0.1:8080/api`. Trong app, địa chỉ này đặt ở **Cài đặt → API Trại nấm** ([S21](S21_SETTINGS.md)); Android emulator dùng `10.0.2.2`, điện thoại thật dùng IP LAN/hostname.

## Kết quả đối chiếu

Các spec S01–S16 trước đây chứa bố cục đề xuất và mục “Cần xác minh”; S17–S19 thiếu chi tiết API. Bộ 2.0 đã cập nhật:

- Login có bước `GET /api/auth/me`, khôi phục phiên và phân biệt lỗi mất phiên với sai quyền.
- Dashboard, danh sách, dialog và tab chi tiết mô tả theo component đang có.
- Công việc bao gồm CRUD, người nhận, minh chứng, lịch sử snapshot, duyệt/trả lại và xử lý `409`.
- Tài chính bao gồm toàn bộ CRUD, Decimal, summary toàn vòng đời và báo cáo theo kỳ.
- Ba gallery bao gồm phân trang, multipart, chú thích, ảnh bìa và cập nhật danh sách.
- Báo cáo/xuất file giữ nguyên bộ lọc; quyền staff, manager và admin được ghi riêng.
- Có danh mục API và OpenAPI ngay trong bộ bàn giao.

## Đồng bộ với giao diện mới (2.1)

Giao diện Flutter được thiết kế lại (xanh rừng + mint, font Be Vietnam Pro, thanh điều hướng dưới có nút Quét ở giữa). Bộ spec đã được sửa cho khớp:

- Thay mô hình route/URL (`/dashboard`, `/batches`…) bằng **5 tab + màn đẩy**; bỏ deep link, `/session`, `/forbidden`, NavigationRail/Sidebar riêng cho khu nội bộ và DataTable.
- Form và chi tiết cơ sở/giống chuyển từ dialog sang **bottom sheet**; danh sách chỉ dùng **card**; biểu đồ thay bằng thanh số liệu kèm chữ.
- Thiết kế chung ([UI_DESIGN_SPEC](UI_DESIGN_SPEC.md)) cập nhật màu, font, bo góc, thanh điều hướng và quy tắc component.
- [S10](S10_CLASSIFIER.md) mô tả đúng tab Quét đang chạy với **dịch vụ AI FastAPI** (upload, WebSocket, polling); contract Node + Socket.IO cũ được giữ làm tham chiếu.
- [S11](S11_CLASSIFIER_HISTORY.md) bổ sung nhánh “Trên máy này”; thêm hai spec mới [S20](S20_AI_CATALOG.md) (Từ điển) và [S21](S21_SETTINGS.md) (Cài đặt) cho các màn đã có trong giao diện.
- Giao diện bổ sung các bộ lọc mà spec yêu cầu nhưng trước đó chưa có: lọc công việc theo lô, lọc nhật ký theo `actorUserId` và `entityId`; đăng xuất có xác nhận.

## Tài liệu bổ trợ

- [ARCHITECTURE.md](ARCHITECTURE.md): cấu trúc mã, hai nguồn dữ liệu, quy ước, mức xác minh.
- [MOCK_DATA.md](MOCK_DATA.md): chế độ **dữ liệu mẫu** (mặc định bật) để chạy thử toàn bộ khu Quản lý mà chưa cần backend; tài khoản demo, dữ liệu khởi tạo, giới hạn.
- `legacy_v1/`: bộ spec cũ của phiên bản dùng dữ liệu giả, **đã lỗi thời**, chỉ giữ để tham khảo.

## Khác biệt đã biết giữa spec và bản build hiện tại

| Nội dung | Tình trạng |
| --- | --- |
| **Dữ liệu mẫu** | Mặc định **bật** để chạy thử không cần backend ([MOCK_DATA](MOCK_DATA.md)); phải tắt và đổi mặc định khi phát hành |
| Token đăng nhập | Lưu trong SharedPreferences, chưa mã hóa; nên chuyển sang secure storage khi phát hành |
| Xuất báo cáo | Chỉ ghi file và hiện đường dẫn; chưa có nút Mở/Chia sẻ; chưa hỗ trợ web |
| Nhận diện | Đi qua dịch vụ AI FastAPI, chưa dùng `/api/mushroom-classifier/classify` + Socket.IO của Node |
| **Giả lập khi mất kết nối** | Dịch vụ hàng đợi tự sinh kết quả ngẫu nhiên khi upload lỗi; giao diện gắn nhãn “KẾT QUẢ GIẢ LẬP”, nên tắt hẳn nhánh này khi phát hành ([S10](S10_CLASSIFIER.md) §3) |
| Ngôn ngữ | Khu Quản lý chỉ có tiếng Việt; Quét/Từ điển/Lịch sử trên máy/Cài đặt/Đăng nhập có VI/EN |
| Nhãn hành động audit | Hiện mã nguyên văn, chưa dịch |
| Ảnh lỗi trong gallery | Có placeholder, chưa có nút tải lại riêng |
| Kiểm thử | Mã mới mới được kiểm tra cú pháp tĩnh; chưa chạy `flutter analyze`, chưa chạy trên thiết bị |

## Nguồn và mức xác nhận

Hành vi ban đầu được đối chiếu với `lib/core`, `lib/shared` và `lib/features` của Flutter; phần giao diện 2.1 đối chiếu với `lib/app`, `lib/core` và `lib/features` của dự án `dacs_mushroom_flutter` (không có `lib/shared`). Route, payload, dữ liệu và quyền được đối chiếu với `swagger.yaml`, `NEW_API_DOCUMENTATION.md`, `FLUTTER_API_INTEGRATION_GUIDE.md` cùng các route/service backend trong `dacs_mushroom_backend`.

Đây là **đối chiếu mã nguồn và contract**, không phải cam kết mọi màn đã được chạy lại trên mọi nền tảng ngày 05/10. Các tiêu chí cuối từng spec là việc ứng dụng mới cần kiểm tra. Những khác biệt backend hiện có được ghi rõ, đặc biệt mốc thời gian của biểu đồ tổng quan và báo cáo tài chính.

`openapi.yaml` được giữ nguyên từ backend, kể cả những schema cũ chỉ mô tả response chung. Khi OpenAPI chưa diễn đạt đầy đủ hành vi, đọc ghi chú và ví dụ trong spec tương ứng. `swagger.yaml` ở gốc project Flutter là bản cũ; dùng bản trong bộ này cho lần bàn giao này. Nếu backend thay đổi, cập nhật đồng thời OpenAPI và các spec bị ảnh hưởng.

Phạm vi không có tồn kho, công nợ, thuế, khấu hao, đăng ký tài khoản hay dịch vụ refresh token.
