# 14 — Feature: Cultivation Batch

## 1. Tổng quan

- **Mục tiêu:** Quản lý các lô nuôi trồng nấm theo cơ sở và giống nấm.
- **Màn hình chính:** `BatchListScreen`
- **Vị trí trong ứng dụng:** Mục thứ 5 trong sidebar của `HomeScreen`.

## 2. Tập tin liên quan

- `lib/features/cultivation_batch/presentation/batch_list_screen.dart`
- `lib/features/cultivation_batch/data/cultivation_batch_model.dart`
- `lib/features/cultivation_batch/presentation/batch_form_sheet.dart`
- `lib/core/network/api_client.dart`

## 3. Quyền truy cập

Tính năng yêu cầu người dùng đăng nhập.

Trong `HomeScreen`:

- Khi `LocalSession.isLoggedIn == true`, hiển thị `BatchListScreen`.
- Khi chưa đăng nhập, hiển thị `_AuthRequiredPlaceholder`.
- Sau khi đăng nhập thành công, Home dựng lại nội dung để hiển thị màn hình lô nuôi trồng.

Việc kiểm tra quyền chi tiết phải được thực hiện ở backend theo tài khoản, vai trò và cơ sở được phân công.

## 4. Chức năng chính

- Xem danh sách các lô nuôi trồng.
- Tìm kiếm hoặc lọc lô theo mã lô, cơ sở, giống nấm, trạng thái hoặc giai đoạn.
- Tạo lô nuôi trồng mới.
- Chỉnh sửa thông tin lô.
- Cập nhật giai đoạn hoặc trạng thái của lô.
- Xem thông tin chi tiết và sản lượng của lô.

## 5. Thông tin của một lô

Một lô nuôi trồng tối thiểu gồm:

- `id`: mã định danh do backend cấp.
- `batchCode`: mã lô.
- `facilityId`: ID cơ sở phụ trách.
- `strainId`: ID giống nấm.
- `startDate`: ngày bắt đầu nuôi trồng.
- `stage`: giai đoạn hiện tại.
- `status`: trạng thái lô.
- `expectedHarvestDate`: ngày dự kiến thu hoạch, nếu có.
- `actualHarvestDate`: ngày thu hoạch thực tế, nếu có.
- `quantity`: số lượng ban đầu, nếu có.
- `yield`: sản lượng thu hoạch, nếu có.
- `notes`: ghi chú.

Các quan hệ với cơ sở và giống nấm phải sử dụng ID, không sử dụng tên hiển thị làm khóa liên kết.

## 6. Giai đoạn nuôi trồng

Lô nuôi trồng hỗ trợ tối thiểu các giai đoạn:

```text
incubation  — Ủ tơ
fruiting    — Ra quả thể
harvesting  — Thu hoạch
completed   — Hoàn tất
```

Việc chuyển giai đoạn phải được kiểm tra hợp lệ ở backend.

## 7. Trạng thái lô

Các trạng thái tối thiểu:

```text
active       — Đang hoạt động
paused       — Tạm dừng
completed    — Đã hoàn tất
cancelled    — Đã hủy
```

Trạng thái hiển thị phải có nhãn bản địa hóa và màu sắc nhất quán với theme ứng dụng.

## 8. Trạng thái giao diện

`BatchListScreen` cần xử lý tối thiểu:

- Đang tải dữ liệu.
- Danh sách rỗng.
- Tải dữ liệu thành công.
- Lỗi khi tải dữ liệu.
- Đang lưu hoặc cập nhật lô.
- Lỗi xác thực hoặc hết hạn phiên đăng nhập.

Khi phiên đăng nhập hết hạn, ứng dụng phải xóa phiên cục bộ và yêu cầu người dùng đăng nhập lại.

## 9. API dự kiến

| Chức năng        | Method                | Endpoint         | Auth     |
| ---------------- | --------------------- | ---------------- | -------- |
| Lấy danh sách lô | `GET`                 | `/batches/`      | Bắt buộc |
| Tạo lô           | `POST`                | `/batches/`      | Bắt buộc |
| Xem chi tiết     | `GET`                 | `/batches/{id}/` | Bắt buộc |
| Cập nhật lô      | `PATCH`               | `/batches/{id}/` | Bắt buộc |
| Xóa hoặc hủy lô  | `DELETE` hoặc `PATCH` | `/batches/{id}/` | Bắt buộc |

Backend phải giới hạn dữ liệu theo cơ sở mà người dùng được phân công.

## 10. Model

Model được khai báo tại:

`lib/features/cultivation_batch/data/cultivation_batch_model.dart`

Model nên là class Dart thuần, các trường dữ liệu chính là `final` và sử dụng named parameters.

Khi API thật được triển khai, bổ sung:

- `CultivationBatchModel.fromJson`
- `CultivationBatchModel.toJson`

ID do backend cấp. Không tiếp tục sử dụng ID tạm sinh bằng `DateTime` sau khi API tạo lô trả về kết quả thành công.

## 11. Điều hướng từ HomeScreen

`BatchListScreen` tương ứng với index `4`:

```text
0 — Nhận diện AI
1 — Từ điển
2 — Cơ sở
3 — Giống nấm
4 — Lô nuôi trồng
5 — Tài khoản
```

Màn hình mặc định của Home vẫn là `MushroomRecognitionScreen` với `initialIndex = 0`.
