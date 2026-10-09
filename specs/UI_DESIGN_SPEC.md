# Đặc tả giao diện — ứng dụng Trại Nấm

**Phiên bản 2.1 · 08/10/2026 · Android, iOS, desktop (web chưa hỗ trợ xuất file).**

Mô tả app Flutter hiện tại sau đợt nâng cấp giao diện; contract chung tại [API_CONTRACT.md](API_CONTRACT.md), schema tại [openapi.yaml](openapi.yaml). [README.md](README.md) giải thích nguồn đối chiếu và các khác biệt đã biết.

## 1. Điều hướng và quyền

App có **một màn Home với 5 tab**; mọi màn con mở bằng đẩy route trong app (`Navigator.push`). **Không có URL route hay deep link.**

| Tab | Nội dung | Quyền |
| --- | --- | --- |
| **Quét** (mặc định) | Nhận diện nấm bằng dịch vụ AI: [S10](S10_CLASSIFIER.md) | Công khai |
| **Từ điển** | Danh mục nấm của dịch vụ AI: [S20](S20_AI_CATALOG.md) | Công khai |
| **Lịch sử** | “Trên máy này” cho mọi người; thêm “Máy chủ” cho manager/admin: [S11](S11_CLASSIFIER_HISTORY.md) | Công khai / manager, admin |
| **Quản lý** | Khách: banner đăng nhập + tra cứu công khai. Đã đăng nhập: Tổng quan [S02](S02_DASHBOARD.md) + lưới chức năng theo vai trò | Xem bên dưới |
| **Cài đặt** | Địa chỉ máy chủ, giao diện, ngôn ngữ, nhật ký: [S21](S21_SETTINGS.md) | Công khai |

Chức năng trong tab **Quản lý** (chức năng không đủ quyền bị **ẩn**, không chỉ làm mờ):

| Mục | Màn | Quyền |
| --- | --- | --- |
| Tra cứu tiến trình lô | [S16](S16_PUBLIC_GROWTH.md) | Công khai |
| Công việc | [S17](S17_TASK_EVIDENCE.md) | admin, manager, staff |
| Lô nuôi | [S03](S03_BATCH_LIST.md), [S04](S04_BATCH_DETAIL.md) | admin, manager, staff |
| Giống nấm / Cơ sở | [S08](S08_MUSHROOM_SPECIES.md), [S09](S09_FACILITIES.md) | admin, manager, staff |
| Báo cáo | [S12](S12_REPORTS.md), [S13](S13_REPORT_EXPORT.md) | admin, manager |
| Nhật ký hệ thống | [S15](S15_AUDIT_LOG.md) | admin, manager |
| Người dùng | [S14](S14_USERS.md) | admin |

Đăng nhập là màn đẩy từ tab Quản lý ([S01](S01_LOGIN.md)); khách vẫn dùng đủ Quét, Từ điển, Lịch sử trên máy, Cài đặt và Tra cứu công khai.

**Quyền thao tác:** mọi role nội bộ được đọc lô/catalog/gallery, sửa lô, ghi chăm sóc/sinh trưởng/thu hoạch. Manager/admin được tạo/xóa lô, CRUD cơ sở/giống, quản lý gallery, giao việc và xem tài chính. Staff chỉ đổi TODO/IN_PROGRESS cho việc mở được giao cho mình và gửi minh chứng; người quản lý được giao việc cũng gửi theo cùng quy tắc, không tự duyệt. Quản lý user chỉ admin. API server luôn là lớp kiểm tra quyền cuối cùng.

## 2. Shell và responsive

| Bề rộng cửa sổ | Shell |
| --- | --- |
| <840 px | Thanh điều hướng dưới dạng thẻ nổi (cao 72 px, bo 30 px). Thứ tự: Từ điển, Lịch sử, **Quét** (nút tròn 56 px ở giữa, nền gradient xanh), Quản lý, Cài đặt. Tab được chọn có nền mint quanh icon |
| ≥840 px | Thanh bên trái rộng 232 px, logo nấm + tên app, 5 mục theo thứ tự Quét, Từ điển, Lịch sử, Quản lý, Cài đặt |

Các tab giữ trạng thái khi chuyển qua lại (`IndexedStack`, tab chỉ được dựng ở lần mở đầu). Tab Lịch sử được tải lại mỗi lần mở. Tab không có AppBar: tiêu đề lớn nằm trong nội dung. Màn đẩy có AppBar trong suốt, tiêu đề đậm.

Danh sách **chỉ dùng card** (không có DataTable); bộ lọc dạng hàng chip cuộn ngang hoặc Wrap, ô nhập nhỏ cho bộ lọc chuỗi. KPI/panel dùng `Wrap` nên tự xuống dòng khi thiếu chỗ.

**Form tạo/sửa** là bottom sheet (tối đa 680 px, cao theo nội dung, cuộn độc lập, footer Hủy/Lưu luôn thấy, tránh bàn phím). Không có dialog toàn màn hình. **Chi tiết cơ sở/giống** mở bottom sheet cao 90%. **Chi tiết lô và công việc** là màn đẩy. **Gửi minh chứng** là bottom sheet cao 92%. Hộp thoại (AlertDialog/Dialog) dùng cho xác nhận, chi tiết audit (cuộn), chi tiết lịch sử nhận diện (tối đa 620 px, cao 80%), xuất báo cáo và popup kết quả nhận diện (tối đa 460 px).

## 3. Thiết kế chung đang sử dụng

Material 3, giao diện sáng/tối. Font **Be Vietnam Pro** (thiết kế cho tiếng Việt) đóng gói trong `assets/fonts` (5 độ đậm 400–800, giấy phép SIL OFL kèm `OFL.txt`); không tải font lúc chạy.

| Thành phần | Sáng | Tối |
| --- | --- | --- |
| Màu chính / nút | `#2F6B1E` | `#5FA02F` |
| Xanh rừng đậm (hero, nút Quét, snackbar) | `#173F0E` | `#173F0E` |
| Mint (nền chip, ô icon, primaryContainer) | `#E3EFD6` | `#243818` |
| Nền ứng dụng | `#F0F5E9` | `#0F160B` |
| Card | `#FFFFFF` | `#1A2414` |
| Viền | `#DCE6CF` | `#2B3922` |
| Chữ chính / phụ | `#14200C` / `#66765A` | `#EAF2E2` / `#9FB08F` |
| Thành công / cảnh báo / lỗi | `#2E7D32` / `#B7791F` / `#C62828` | cùng màu, nền nhạt tương ứng |

| Thành phần | Giá trị |
| --- | --- |
| Hero gradient | `#1F4F12` → `#173F0E` → `#0F2A09` (chéo từ trên-trái) |
| Card (`SoftCard`) | Bo 20 px, viền 1 px, bóng `#173F0E` 5% mờ 18 px lệch (0, 6); vùng chạm có hiệu ứng gợn cắt theo góc bo |
| Input / nút Filled / Outlined | Bo 16 px; nút cao tối thiểu 52 px (nút form chính 54 px) |
| Chip | Hình viên thuốc; chip chọn đổi sang nền màu chính |
| Dialog / bottom sheet | Bo 28 px; sheet có tay kéo |
| Chữ | Tiêu đề lớn 26/800; tiêu đề mục 16/700; nội dung 14; chú thích 12; nhãn 11–14 |
| Khoảng cách | Lề trang 20 px; 10–16 px giữa card/panel |
| Chip trạng thái (`StatusChip`) | Chấm màu + chữ 12/700 trên nền màu 12% |
| Nhãn trạng thái | Luôn có chữ đi kèm màu (không chỉ dựa vào màu) |

Hình minh họa nấm là `MushroomGlyph` vẽ bằng code (không cần asset), màu mũ lấy ổn định theo tên loài, nhóm đỏ–cam–tím cho nấm độc. Ảnh server hiển thị bằng `NetImage` (ghép origin cho `/uploads/...`, placeholder khi rỗng/lỗi, bấm để phóng to). Dữ liệu null hiển thị “—” hoặc “Chưa có dữ liệu” theo ngữ cảnh; không biến null thành số 0 để làm KPI.

**Ngôn ngữ:** các màn **Quét, Từ điển, Lịch sử trên máy, Cài đặt, Đăng nhập** hỗ trợ VI/EN qua `tr()`. Các màn nghiệp vụ trong tab Quản lý (S02–S09, S12–S19) hiện chỉ có tiếng Việt.

## 4. Component và hành vi chung

- **Danh sách phân trang** (`PagedListView`): search chỉ gọi API khi Enter/Done, xóa search bỏ bộ lọc ngay; đổi bộ lọc về trang 1; nút Trước/Sau bị khóa khi đang tải hoặc hết trang; kết quả của truy vấn cũ đến muộn bị bỏ qua; kéo xuống để tải lại; thanh tiến trình mảnh khi đang tải lại mà vẫn giữ nội dung cũ.
- **Reference picker:** bottom sheet có search + phân trang, giữ lựa chọn qua trang, bấm Xác nhận mới áp dụng, lưu **ID** thay vì object. Picker một giá trị có nút “Bỏ chọn”; đóng sheet mà không bấm gì **giữ nguyên** giá trị cũ.
- **Form** (`showFormSheet`): chỉ gửi allowlist field của form. Trim chuỗi thường, giữ nguyên password. Field tùy chọn trống khi tạo bị bỏ khỏi body; khi sửa gửi `null` nếu field được đánh dấu có thể xóa. Số tiền/số lượng Decimal giữ nguyên dạng **chuỗi**, không qua double; chấp nhận dấu phẩy thập phân. Lỗi API hiện trong khung đỏ trên form và giữ nguyên dữ liệu đã nhập. Users có ngoại lệ ở [S14](S14_USERS.md).
- Ngày hiển thị theo giờ local thiết bị; timestamp form đổi sang ISO UTC (ô chỉ-ngày gửi 12:00 local để không lệch ngày). Ngày báo cáo là `YYYY-MM-DD` theo ranh giới UTC+7 của server.
- Chọn ảnh kiểm tra JPEG/PNG/WebP, ≤5 MiB và số lượng **trước khi gửi**; gỡ ảnh mới chọn không có nghĩa xóa ảnh trên server.
- Gửi mutation một lần, khóa nút khi đang gửi. Lỗi giữ dữ liệu nhập; không tự lặp POST/PATCH/DELETE. `409` thì tải lại dữ liệu và báo trạng thái đã đổi.
- Loading, rỗng, lỗi (có nút Tải lại) và thành công luôn phân biệt. Refresh sau mutation theo từng spec; **không tự tạo số liệu hoặc bản ghi giả** trong khu quản lý, trừ **chế độ dữ liệu mẫu** do người dùng chủ động bật ([MOCK_DATA](MOCK_DATA.md)): khi đó tab Quản lý luôn hiện băng vàng “Đang dùng DỮ LIỆU MẪU” và màn Đăng nhập hiện khung tài khoản demo.
- Đăng xuất luôn có hộp thoại xác nhận. Token hết hạn (401, hoặc 403 `AUTH_INVALID_TOKEN`) xóa phiên và đưa tab Quản lý về trạng thái khách; `403 AUTH_FORBIDDEN` giữ phiên.

## 5. Mục lục màn hình

| Spec | Màn / chức năng | Vị trí trong UI |
| --- | --- | --- |
| [S01](S01_LOGIN.md) | Đăng nhập, khôi phục và xác nhận phiên | Màn đẩy từ tab Quản lý |
| [S02](S02_DASHBOARD.md) | Tổng quan | Đầu tab Quản lý |
| [S03](S03_BATCH_LIST.md) | Danh sách và tạo lô | Quản lý → Lô nuôi |
| [S04](S04_BATCH_DETAIL.md) | Chi tiết, sửa/xóa lô và các tab | Màn đẩy |
| [S05](S05_CARE_LOGS.md) | Ghi chăm sóc | Tab của chi tiết lô |
| [S06](S06_HARVESTS.md) | Ghi thu hoạch | Tab của chi tiết lô |
| [S07](S07_GROWTH_PROGRESS.md) | Nhật ký sinh trưởng và ảnh | Tab của chi tiết lô |
| [S08](S08_MUSHROOM_SPECIES.md) | Giống nấm | Quản lý → Giống nấm |
| [S09](S09_FACILITIES.md) | Cơ sở | Quản lý → Cơ sở |
| [S10](S10_CLASSIFIER.md) | Nhận diện nấm (dịch vụ AI FastAPI) | Tab Quét |
| [S11](S11_CLASSIFIER_HISTORY.md) | Lịch sử nhận diện (trên máy + máy chủ) | Tab Lịch sử |
| [S12](S12_REPORTS.md) | Báo cáo tổng quan/nuôi trồng/nhận diện/hoạt động | Quản lý → Báo cáo |
| [S13](S13_REPORT_EXPORT.md) | Xuất CSV/XLSX/PDF, cả tài chính | Hộp thoại từ Báo cáo |
| [S14](S14_USERS.md) | Users và roles | Quản lý → Người dùng |
| [S15](S15_AUDIT_LOG.md) | Nhật ký hệ thống | Quản lý → Nhật ký hệ thống |
| [S16](S16_PUBLIC_GROWTH.md) | Tra cứu tiến trình công khai | Đăng nhập / Quản lý / chi tiết lô |
| [S17](S17_TASK_EVIDENCE.md) | Công việc, minh chứng và duyệt | Quản lý → Công việc |
| [S18](S18_FINANCIALS.md) | Tài chính lô và báo cáo tài chính | Tab của chi tiết lô; Báo cáo |
| [S19](S19_ENTITY_GALLERY.md) | Gallery cơ sở, giống và lô | Sheet chi tiết; tab Ảnh của lô |
| [S20](S20_AI_CATALOG.md) | Từ điển nấm (danh mục của dịch vụ AI) | Tab Từ điển |
| [S21](S21_SETTINGS.md) | Cài đặt | Tab Cài đặt |

Tài liệu bổ trợ: [ARCHITECTURE](ARCHITECTURE.md) (cấu trúc mã và luồng dữ liệu), [MOCK_DATA](MOCK_DATA.md) (chế độ dữ liệu mẫu).

## 6. Nghiệm thu ứng dụng mới

Kiểm tra 360/390/768/1440 px, cỡ chữ lớn, bàn phím mở và nội dung dài: không overflow, nút form vẫn tới được, ảnh có thể phóng to. Kiểm tra 401/403 theo từng role, đăng nhập hết hạn giữa chừng, mất mạng/refresh, danh sách rỗng, mutation lỗi và chống nhấn đôi. Kiểm tra chế độ sáng và tối, VI và EN ở các màn có hỗ trợ. Tiêu chí chi tiết nằm ở từng Sxx; các mục này không phải báo cáo đã chạy lại mọi màn.
