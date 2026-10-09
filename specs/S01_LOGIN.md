# S01 — Đăng nhập và xác nhận phiên

**Vị trí:** màn Đăng nhập mở từ tab **Quản lý** (nút Đăng nhập); trạng thái chờ xác nhận hiển thị ngay trong tab Quản lý, không có route `/session`. **Quyền:** công khai. [Quy tắc chung](UI_DESIGN_SPEC.md) · [API](API_CONTRACT.md).

## Giao diện và luồng

Màn Đăng nhập có banner xanh với hình nấm, nút quay lại, form username/password (icon tiền tố, nút hiện/ẩn password), nút Đăng nhập, nút **Tra cứu tiến trình lô** ([S16](S16_PUBLIC_GROWTH.md)) và nút **Dùng Nhận diện & Từ điển, không cần đăng nhập**. Kiểm tra hai field không trống; username trim, password giữ nguyên. Khóa gửi khi đang xử lý, hiện lỗi phía trên và giữ input.

1. POST login, nhận token và lưu vào SharedPreferences (chưa mã hóa; khi phát hành nên chuyển sang secure storage). Ở **chế độ dữ liệu mẫu** ([MOCK_DATA](MOCK_DATA.md)) lệnh này do backend giả trả lời và màn Đăng nhập hiện sẵn tài khoản demo để bấm điền.
2. GET auth/me bằng token vừa nhận.
3. Chỉ vào khu vực nội bộ khi profile có ID dương, username và role admin/manager/staff.
4. Đóng màn Đăng nhập về màn trước (nếu là route gốc thì mở Home). Tab Quản lý lắng nghe `LocalSession.changes` nên tự chuyển sang trạng thái đã đăng nhập và hiện Tổng quan. Bản này không có deep link `from`.

Khởi động app: đọc token đã lưu → GET auth/me chạy nền, không chặn màn hình khởi động; không có token → chế độ khách. Không lấy role từ JWT hoặc cho user chọn role. Profile chưa xác nhận do endpoint chưa có/503/dữ liệu không hợp lệ: giữ token ở trạng thái chờ, tab Quản lý hiện khung “Chưa xác nhận được phiên đăng nhập” với nút Thử lại và Đăng xuất, dữ liệu nội bộ chưa hiển thị; không coi là signed-in.

Đăng xuất có hộp thoại xác nhận, xóa token lưu và token transport rồi về chế độ khách; không gọi endpoint logout. Token không hợp lệ/hết hạn xóa phiên theo contract chung; 403 sai quyền giữ phiên.

## API call

| Method / path | Body / response | Thời điểm |
| --- | --- | --- |
| POST /api/login | `{username,password}` → 200 `{message,token}` | Submit login, không Authorization |
| GET /api/auth/me | 200 `{data:{id,username,full_name,role,email,phone_number}}` | Sau login, restore, retry session; Bearer |

```json
{
  "username": "nhanvien",
  "password": "mat-khau"
}
```

Profile ví dụ:

```json
{
  "data": {
    "id": 7,
    "username": "nhanvien",
    "full_name": "Nguyễn Văn A",
    "role": "staff"
  }
}
```

Password sai → 401. Không có đăng ký, quên mật khẩu hoặc refresh-token API trong app hiện tại. Không log password/token.

## Kiểm tra

- [ ] Login thiếu field không gọi API; nhấn đôi chỉ gửi một lần.
- [ ] POST thành công nhưng GET me lỗi không mở màn nội bộ.
- [ ] Restore đúng quyền; role lạ/profile hỏng đi vào trạng thái chờ.
- [ ] Sau đăng nhập tab Quản lý tự hiện Tổng quan; token hết hạn giữa chừng đưa tab về trạng thái khách.
- [ ] Public vẫn hoạt động khi chưa đăng nhập; logout xóa phiên; AUTH_FORBIDDEN không tự logout.
