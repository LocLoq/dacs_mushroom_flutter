# S08 — Giống nấm

**Vị trí:** Quản lý → Giống nấm. **Quyền:** mọi role nội bộ xem; manager/admin tạo/sửa/xóa.

## Giao diện và luồng

Catalog có search, list 10/trang, ảnh bìa/số ảnh, tên thường/tên khoa học, khả năng ăn, độ khó nuôi và thao tác. Chỉ có filter search trong UI hiện tại; không thêm filter độ khó/khả năng ăn chỉ vì backend có dữ liệu.

Nhấn xem mở bottom sheet tối đa 680 px, cao 90% màn hình; **GET chi tiết từ server**, không dùng row list làm toàn bộ detail. Sheet có thông tin giống và gallery lazy load khi mở; staff chỉ xem. Manager/admin có nút nổi “Thêm giống”. Form CRUD dùng bottom sheet chung; xóa có xác nhận.

Ảnh list dùng coverImageUrl, dự phòng imageUrl cũ khi không có bìa. Gallery giống rỗng có thể hiện ảnh cũ theo response, xem [S19](S19_ENTITY_GALLERY.md).

## API call

| Method / path | Query / body | Response |
| --- | --- | --- |
| GET /api/mushroom-species | page, limit, search | 200 data/pagination |
| GET /api/mushroom-species/{id} | ID integer | 200 data |
| POST /api/mushroom-species | JSON, manager/admin | 201 message/data |
| PUT /api/mushroom-species/{id} | JSON, manager/admin | 200 message/data |
| DELETE /api/mushroom-species/{id} | Manager/admin | 200 message |
| GET /api/mushroom-species/{id}/images | page, limit | 200 data/pagination; S19 |

Search backend theo commonName/scientificName/otherNames/family/genus; thứ tự createdAt giảm dần. Không tải gallery cho từng row.

## Field form

Bắt buộc theo app: `commonName,scientificName,family,genus,edibilityStatus`.

Tùy chọn: `otherNames,cultivationDifficulty,ecologyType,capDescription,gillsDescription,stemDescription,sporePrintColor,bruisingBehavior,habitat,fruitingSeason,toxicitySymptoms,medicinalProperties,imageUrl`.

| Enum | Giá trị |
| --- | --- |
| edibilityStatus | CHOICE, EDIBLE, INEDIBLE, POISONOUS, DEADLY |
| cultivationDifficulty | EASY, MEDIUM, HARD, UNCULTIVABLE |
| ecologyType | SAPROBIC, MYCORRHIZAL, PARASITIC |

```json
{
  "commonName": "Nấm bào ngư",
  "scientificName": "Pleurotus ostreatus",
  "family": "Pleurotaceae",
  "genus": "Pleurotus",
  "edibilityStatus": "EDIBLE",
  "cultivationDifficulty": "EASY",
  "ecologyType": "SAPROBIC",
  "habitat": "Gỗ mục"
}
```

Giống không có field notes trong form/allowlist. Không gửi metadata, coverImageUrl/imageCount hoặc images. Các mô tả dùng field chuyên biệt như habitat/capDescription.

Sau CRUD tải lại list; sau gallery mutation tải lại gallery, GET detail và list. ScientificName trùng/field sai trả lỗi, giữ form.

## Kiểm tra

- [ ] View gọi GET detail, list chỉ tải cover/count.
- [ ] Staff không có CRUD/gallery mutation.
- [ ] Đúng enum giống; không dùng enum POISONOUS/NON_POISONOUS/UNKNOWN của classifier.
- [ ] Gallery/CRUD cập nhật bìa/số ảnh; ảnh legacy chỉ làm dự phòng.
