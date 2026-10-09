# S09 — Cơ sở sản xuất

**Vị trí:** Quản lý → Cơ sở. **Quyền:** mọi role nội bộ xem; manager/admin CRUD.

## Giao diện

Search và danh sách 10/trang với ảnh bìa/số ảnh, tên, tỉnh, loại, trạng thái; chỉ dùng card. Xem mở bottom sheet tối đa 680 px, cao 90% màn hình, GET detail rồi hiển thị thông tin, các giống liên kết và gallery [S19](S19_ENTITY_GALLERY.md).

Form tạo/sửa chung; chọn nhiều giống bằng reference picker, giữ lựa chọn qua search/trang. Xóa có xác nhận, lỗi không tự loại dòng. App hiện không có quy tắc chặn tạo lô theo status cơ sở ở frontend.

## API call

| Method / path | Query / body | Response |
| --- | --- | --- |
| GET /api/production-facilities | page, limit, search | 200 data/pagination |
| GET /api/production-facilities/{id} | ID integer | 200 data cùng mushrooms |
| POST /api/production-facilities | JSON | 201 message/data |
| PUT /api/production-facilities/{id} | JSON | 200 message/data |
| DELETE /api/production-facilities/{id} | Không body | 200 message |
| GET /api/mushroom-species | page, limit, search trong picker | 200 data/pagination |
| GET /api/production-facilities/{id}/images | page, limit | 200 data/pagination |

POST/PUT/DELETE chỉ manager/admin. Search backend theo tên/địa chỉ/tỉnh/mã thuế.

## Field form

Bắt buộc: `name,address,facilityType,status`. Province tùy chọn theo app hiện tại.

Tùy chọn: `province,taxCode,contactPhone,contactEmail,capacityTonsPerYear,totalAreaSqm,certifications,mushrooms`. Hai số công suất/diện tích là JSON number ≥0; certifications là chuỗi. Mushrooms trong **request là integer ID array**, trong **response là object array**.

Enum facilityType: `HOUSEHOLD` Hộ gia đình, `COOPERATIVE` Hợp tác xã, `ENTERPRISE` Doanh nghiệp. Status: `ACTIVE`, `SUSPENDED`, `CLOSED`; tạo mặc định ACTIVE.

```json
{
  "name": "Trại nấm A",
  "address": "12 Đường số 1",
  "province": "Đồng Nai",
  "facilityType": "HOUSEHOLD",
  "status": "ACTIVE",
  "capacityTonsPerYear": 12.5,
  "totalAreaSqm": 500,
  "mushrooms": [2, 3]
}
```

Không gửi id, quan hệ object, cover/count hoặc timestamps. PUT `mushrooms:[]` bỏ toàn bộ liên kết; bỏ field mushrooms giữ liên kết. Sau CRUD refresh list; gallery refresh gallery/detail/list.

## Kiểm tra

- [ ] Multi-picker giữ ID qua nhiều trang, gửi array số, không object.
- [ ] Số âm bị chặn; tùy chọn tỉnh không bị đổi thành bắt buộc.
- [ ] Staff xem được detail/ảnh nhưng không mutation.
- [ ] Xóa có xác nhận; đổi bìa cập nhật list.
