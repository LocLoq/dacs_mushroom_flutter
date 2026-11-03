# Dữ liệu mẫu (chế độ demo)

Cho phép chạy thử **toàn bộ khu Quản lý** — đăng nhập, Tổng quan, lô, công việc, báo cáo… — mà **chưa cần backend**. Đây là công cụ phát triển/trình diễn, không phải dữ liệu thật.

## Bật/tắt và nhận biết

- Công tắc **Dùng dữ liệu mẫu** ở **Cài đặt → API Trại nấm** ([S21](S21_SETTINGS.md)). **Mặc định BẬT.** Đổi công tắc luôn **xóa phiên đăng nhập hiện tại** (token của chế độ này không dùng được ở chế độ kia). Giá trị lưu ở SharedPreferences, khóa `farm_mock_mode`.
- Khi bật: tab **Quản lý** luôn hiện băng vàng “Đang dùng DỮ LIỆU MẪU: không gọi backend, thay đổi mất khi mở lại app”; màn **Đăng nhập** hiện khung tài khoản demo, bấm một chip để điền sẵn tên đăng nhập và mật khẩu.
- Nút “Lưu và kiểm tra” ở Cài đặt không gọi mạng khi đang ở chế độ mẫu mà báo như vậy.
- Tab **Quét** và **Từ điển** dùng dịch vụ AI riêng nên **không** thuộc chế độ này (xem cảnh báo kết quả giả lập ở [S10](S10_CLASSIFIER.md) §3).

## Cách hoạt động

Mọi lệnh của `FarmApi` (`get/post/put/patch/delete/multipart/download` và đăng nhập) được chuyển cho `MockBackend` — một backend giả **trong bộ nhớ** — thay vì gửi HTTP. Giao diện không biết sự khác biệt: cùng envelope `{data, pagination}`, cùng mã lỗi, cùng đường dẫn như [API_CONTRACT](API_CONTRACT.md). Mỗi lệnh trễ ~220 ms (tải file ~400 ms) để thấy trạng thái loading; kết quả được sao chép sâu như dữ liệu qua mạng. **Dữ liệu chỉ sống trong phiên chạy:** mở lại app là về dữ liệu khởi tạo.

Tắt công tắc là đủ để chuyển sang API thật; không cần sửa màn hình nào.

## Tài khoản

| Tên đăng nhập | Mật khẩu | Vai trò |
| --- | --- | --- |
| `admin` | `admin123` | admin |
| `manager` | `manager123` | manager |
| `staff` | `staff123` | staff |
| `nhanvien2` | `password123` | staff |
| `quanly2` | `password123` | manager |

Token là chuỗi `mock-{username}`; token lạ trả `401 AUTH_INVALID_TOKEN` và xóa phiên giống server thật.

## Dữ liệu khởi tạo

Ngày tháng tính tương đối theo hôm nay nên Tổng quan/Báo cáo luôn có số liệu “gần đây”.

| Nhóm | Nội dung |
| --- | --- |
| Giống nấm | 9 loài (Nấm Rơm, Bào Ngư, Linh Chi, Mộc Nhĩ, Nấm Mỡ, Đùi Gà, Kim Châm, Hương và Nấm Tử Thần — cực độc, không nuôi được) |
| Cơ sở | 4 (một tạm ngưng), mỗi cơ sở liên kết một số giống |
| Lô nuôi | 12 lô `LO-2026-001…012` đủ 6 trạng thái, có lô trễ hạn và lô thất bại |
| Theo lô | 3 nhật ký chăm sóc (trừ lô Chuẩn bị), 1–2 nhật ký sinh trưởng, 2–3 lần thu hoạch cho lô Thu hoạch/Hoàn thành, 3 khoản chi, 1–2 lần bán |
| Công việc | 8 việc đủ trạng thái; việc **#4 đang chờ duyệt** với một lần gửi của `staff` có hai minh chứng; việc #1 giao cho `staff` để thử gửi minh chứng |
| Người dùng | 5 (xem bảng trên) và 3 vai trò |
| Nhật ký hệ thống | 60 bản ghi trải khoảng 22 ngày, cứ 7 bản có 1 bản thất bại |
| Lịch sử nhận diện (máy chủ) | 14 lượt: thành công, thất bại, đang chờ |
| Ảnh gallery | Trống; tải ảnh thì thêm vào danh sách |

## Endpoint được hỗ trợ

| Nhóm | Đường dẫn | Spec |
| --- | --- | --- |
| Xác thực | `POST /login`, `GET /auth/me` | [S01](S01_LOGIN.md) |
| Lô | `/cultivation-batches` (CRUD), `…/care-logs`, `…/harvests`, `…/growth-progress` (POST/PATCH multipart), `…/expenses`, `…/sales`, `…/financial-summary`, `…/images` | [S03](S03_BATCH_LIST.md)–[S07](S07_GROWTH_PROGRESS.md), [S18](S18_FINANCIALS.md), [S19](S19_ENTITY_GALLERY.md) |
| Giống, cơ sở | `/mushroom-species`, `/production-facilities` (CRUD) và `…/images` | [S08](S08_MUSHROOM_SPECIES.md), [S09](S09_FACILITIES.md) |
| Công việc | `/dashboard/tasks` (CRUD), `…/submissions`, `…/submissions/{id}/review`, `…/evidence-candidates`, `/dashboard/task-assignees` | [S17](S17_TASK_EVIDENCE.md), [S02](S02_DASHBOARD.md) |
| Quản trị | `/admin/users` (CRUD), `/admin/roles`, `/admin/audit-logs` | [S14](S14_USERS.md), [S15](S15_AUDIT_LOG.md) |
| Báo cáo | `/reports/{overview, cultivation, financial, classifier, audit}` và `…/export` | [S12](S12_REPORTS.md), [S13](S13_REPORT_EXPORT.md) |
| Nhận diện (máy chủ) | `/mushroom-classifier/history` (danh sách, chi tiết) | [S11](S11_CLASSIFIER_HISTORY.md) |
| Công khai | `/public/cultivation-batches/{code}/growth-progress/current` | [S16](S16_PUBLIC_GROWTH.md) |

Không hỗ trợ: gửi ảnh nhận diện lên `/mushroom-classifier/classify` (tab Quét dùng dịch vụ AI riêng, [S10](S10_CLASSIFIER.md)), Socket.IO.

## Quy tắc quyền và lỗi được mô phỏng

- **401** token sai/hết hạn (xóa phiên). **403** `AUTH_FORBIDDEN`: staff gọi báo cáo, nhật ký, quản trị, tạo/xóa lô, CRUD giống/cơ sở, gallery ghi, tài chính, giao việc, duyệt; ngoài việc được giao thì staff cũng không đổi trạng thái công việc được.
- **404** không thấy bản ghi hoặc mã lô công khai. **409** trùng mã lô/username; xóa giống/cơ sở đang được lô dùng; xóa việc đã có lịch sử; gửi minh chứng khi việc không còn mở; duyệt lần gửi không còn chờ; đổi lô/người nhận khi đang chờ duyệt; xóa chính tài khoản đang đăng nhập. **422** thiếu hoặc sai dữ liệu bắt buộc (sản lượng âm, ảnh >5, evidence ngoài 1–20…).
- Không tự duyệt minh chứng của chính mình (403). Duyệt: APPROVE → việc Hoàn thành; REJECT (bắt buộc lý do) → việc về Đang thực hiện. Ghi thu hoạch với `finalizeBatch` đưa lô sang Hoàn thành; thu hoạch thường tự đưa lô sớm hơn sang Thu hoạch (mô phỏng việc server tự quyết trạng thái).
- Hầu hết thao tác tạo/sửa/xóa (lô, giống, cơ sở, chăm sóc, thu hoạch, sinh trưởng, chi/bán, công việc, người dùng, tải ảnh, xuất báo cáo) thêm một dòng vào Nhật ký hệ thống; sửa/xóa chi–bán và sửa sinh trưởng thì chưa ghi.

## Khác biệt so với API thật (giới hạn đã biết)

| Nội dung | Bản mẫu |
| --- | --- |
| Ảnh tải lên | Không lưu file; trả URL `/uploads/mock/…` nên giao diện hiện **placeholder** |
| Xuất báo cáo | **Luôn CSV** dù chọn CSV/XLSX/PDF, tên `mock-{loại}-report.csv` |
| Tiền | Tính bằng số thực rồi định dạng 2 chữ số thập phân; server thật dùng Decimal |
| Công việc | Staff thấy mọi công việc; “minh chứng của bạn” là mọi nhật ký của lô (hoặc mọi lô nếu việc chưa gắn lô) |
| Lịch sử nhận diện | Chỉ đọc; lượt quét ở tab Quét không ghi vào đây |
| Ràng buộc khác | Không giới hạn độ dài trường, không rate-limit, tìm kiếm đơn giản (chứa chuỗi, không phân biệt hoa/thường) |
| Múi giờ | Lọc ngày theo UTC của thiết bị, không dùng quy ước UTC+7 của server |

## Kiểm tra

Bộ test `test/mock_backend_test.dart` (7 test) kiểm tra qua đúng lớp `FarmApi`: đăng nhập đúng/sai, staff bị chặn báo cáo, phân trang lô, 409 trùng mã lô, tiền dạng chuỗi, luồng giao việc → gửi minh chứng → duyệt, tra cứu công khai (kể cả 404). Chạy bằng `flutter test`; **chưa được chạy** khi viết tài liệu này.

- [ ] Bật chế độ mẫu, đăng nhập 3 vai trò: mục và nút hiện/ẩn đúng quyền ([UI_DESIGN_SPEC](UI_DESIGN_SPEC.md) §1).
- [ ] Băng cảnh báo hiện ở tab Quản lý; tắt công tắc thì mất băng và phiên bị xóa.
- [ ] Mở lại app: dữ liệu về trạng thái khởi tạo.
- [ ] **Không** bật chế độ mẫu trong bản phát hành; nên đổi mặc định sang tắt (`MockConfig`).
