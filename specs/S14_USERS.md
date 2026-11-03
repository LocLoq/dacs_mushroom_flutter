# S14 — Quản lý người dùng

**Vị trí:** Quản lý → Người dùng (mục chỉ hiện với admin). **Quyền:** chỉ admin; manager/staff bị chặn route và API.

## Giao diện và hành vi

List 10/trang, search username/họ tên; hiển thị tài khoản, full_name, liên hệ, vai trò và sửa/xóa. Thứ tự ID giảm dần. Form tạo/sửa dùng bottom sheet chung. Xóa có xác nhận, chỉ refresh sau server thành công.

Mỗi lần mở form gọi GET roles trước; **không hardcode role_id**. Sửa dùng dữ liệu row trong list, không có GET user detail. Username khi sửa bị khóa và không gửi. Password trống khi sửa được bỏ khỏi body; không log, hiển thị password/hash hoặc prefill password.

## API call

| Method / path | Body / response |
| --- | --- |
| GET /api/admin/users | page, limit, search → 200 data/pagination |
| GET /api/admin/roles | 200 data array roles, không pagination |
| POST /api/admin/users | JSON → 201 message/data |
| PUT /api/admin/users/{id} | JSON field cho phép → 200 message/data |
| DELETE /api/admin/users/{id} | 200 message |

Role: `{id:integer,name:"admin"|"manager"|"staff"}`. User list gồm `id,username,full_name,phone_number,email,role_id,role:{name}` và có thể metadata hệ thống. DTO role **khác** auth/me.role string.

## Field và payload

Tạo: app bắt buộc `username,password,full_name,phone_number,email,role_id`. Role ID là integer thực từ GET roles.

```json
{
  "username": "nhanvien_moi",
  "password": "mat-khau",
  "full_name": "Nguyễn Văn B",
  "phone_number": "0900000000",
  "email": "nhanvien@example.com",
  "role_id": 3
}
```

Sửa: `full_name` bắt buộc; `phone_number,email` chỉ mở sửa khi row có field tương ứng; `password` tùy chọn; `role_id` chỉ gửi khi đổi. PUT không gửi username/id/role object/token version/hash.

```json
{
  "full_name": "Nguyễn Văn B",
  "email": "emailmoi@example.com"
}
```

Backend hiện cập nhật các field liên hệ theo giá trị truthy: **null/chuỗi rỗng không xóa phone/email**, giữ giá trị cũ. Không hứa chức năng xóa liên hệ chưa được backend hỗ trợ. Gửi role_id/password làm tăng phiên bản token; app bỏ role_id không đổi để sửa liên hệ không vô tình làm token mất hiệu lực. Đổi role/password thật có thể buộc user đăng nhập lại.

Không có role CRUD, trang self-profile hoặc reset-password riêng. Lỗi xóa do tham chiếu/validation hiển thị message, không tự xóa row.

## Kiểm tra

- [ ] Manager/staff không gọi admin/users/roles.
- [ ] Roles lỗi có retry, không thay bằng ID giả.
- [ ] Sửa liên hệ không gửi password trống hoặc role_id không đổi.
- [ ] PUT chỉ field hợp lệ; role/password đổi dẫn tới xác nhận phiên lại theo backend.
- [ ] Hành vi bỏ trống liên hệ khớp backend, không báo đã xóa dữ liệu thực tế còn nguyên.
