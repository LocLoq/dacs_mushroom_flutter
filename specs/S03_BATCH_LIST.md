# S03 — Danh sách và tạo lô

**Vị trí:** Quản lý → Lô nuôi; nhận trạng thái ban đầu từ chip ở Tổng quan. **Quyền:** mọi role nội bộ; tạo lô chỉ manager/admin.

## Giao diện và hành vi

Search mã lô, lọc trạng thái/cơ sở/giống; picker cơ sở/giống có search và phân trang. Danh sách 10 dòng/trang: ảnh bìa/số ảnh, mã lô, giống, cơ sở, trạng thái, ngày bắt đầu và mở chi tiết. Chỉ dùng card (không có bảng). Trạng thái là hàng ChoiceChip (Tất cả + 6 trạng thái); Cơ sở/Giống là ActionChip mở bộ chọn có nút “Bỏ chọn”. Search gửi khi Enter, đổi filter về page 1.

Chỉ tải coverImageUrl/imageCount từ response list, không tải gallery cho từng dòng. Nhấn dòng mở [S04](S04_BATCH_DETAIL.md). Danh sách có nút nổi “Tạo lô” cho manager/admin; sửa/xóa nằm trong chi tiết lô.

## API call

| Method / path | Query / body | Response |
| --- | --- | --- |
| GET /api/cultivation-batches | page, limit, search, status, facilityId, mushroomId | 200 data/pagination |
| GET /api/production-facilities | page=1, limit=10, search; đổi page trong picker | 200 data/pagination |
| GET /api/mushroom-species | page=1, limit=10, search; đổi page trong picker | 200 data/pagination |
| POST /api/cultivation-batches | JSON form, manager/admin | 201 message/data |

List mặc định page 1, limit 10, tối đa 50. Search theo batchCode; server sắp startDate giảm dần. Một dòng có ID số nguyên, các field lô, `facility:{id,name,facilityType}`, `mushroom:{id,commonName,scientificName}`, `coverImageUrl` nullable và `imageCount`.

## Form dùng chung tạo/sửa

| Field | Nhập / yêu cầu của app |
| --- | --- |
| batchCode | Chuỗi bắt buộc |
| facilityId, mushroomId | ID integer bắt buộc từ picker |
| status | Bắt buộc, mặc định PREPARATION khi tạo |
| startDate | Ngày bắt buộc, mặc định hiện tại |
| expectedHarvestDate, endDate | Ngày tùy chọn, có thể null khi sửa |
| substrateType, spawnSource, notes | Chuỗi tùy chọn |
| bagQuantity | Integer ≥0, tùy chọn |
| defectRate | JSON number 0–100, tùy chọn |

Enum trạng thái: `PREPARATION` Chuẩn bị; `INCUBATION` Ủ tơ; `FRUITING` Ra quả thể; `HARVESTING` Thu hoạch; `COMPLETED` Hoàn thành; `FAILED` Thất bại.

```json
{
  "batchCode": "LO-2026-001",
  "facilityId": 1,
  "mushroomId": 2,
  "status": "PREPARATION",
  "startDate": "2026-10-04T17:00:00.000Z",
  "expectedHarvestDate": "2026-11-04T17:00:00.000Z",
  "substrateType": "Mùn cưa",
  "bagQuantity": 1000,
  "notes": "Lô thử nghiệm"
}
```

Ngày chọn chuyển ISO UTC. Không gửi facility/mushroom lồng, id, cover/count, timestamps hoặc actualYieldKg; sản lượng thực tế lấy theo thu hoạch. Sau tạo tải lại list; lỗi giữ form. Mã trùng hoặc tham chiếu sai do backend trả lỗi, không tạo dòng tạm như đã thành công.

## Kiểm tra

- [ ] Staff chỉ xem/đi vào chi tiết, không có nút tạo.
- [ ] Filter giữ khi phân trang/quay lại; search cũ trả chậm không thay kết quả mới.
- [ ] Picker gửi ID integer; form kiểm tra bagQuantity/defectRate.
- [ ] List hiển thị bìa/số ảnh từ server, không gọi N gallery request.
