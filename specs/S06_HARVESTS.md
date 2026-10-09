# S06 — Thu hoạch

**Vị trí:** tab Thu hoạch của lô hoặc ghi ngay từ công việc. **Quyền:** mọi role nội bộ được xem/ghi.

## Giao diện và hành vi

Card sản lượng kg, ngày thu hoạch, chất lượng, ghi chú. Tổng kg trong tab cộng **toàn bộ array server trả về**; đây là thông tin thu hoạch lô, không phải doanh thu/báo cáo theo kỳ. Không phân trang care/growth/harvest.

Form gồm totalYieldKg bắt buộc, qualityGrade chuỗi tự do tùy chọn, harvestedAt mặc định hiện tại, notes tùy chọn, finalizeBatch checkbox mặc định false. Sản lượng là JSON number **≥0**, app/backend cho phép 0; không áp dụng quy tắc quantity >0 của tài chính. Dấu phẩy nhập số được chuẩn hóa.

Chọn finalizeBatch phải xác nhận hoàn thành lô. Backend ghi thu hoạch, cộng sản lượng và cập nhật trạng thái COMPLETED/endDate trong transaction; UI tải lại lô thay vì tự giả định thành công.

## API call

| Method / path | Body / response |
| --- | --- |
| GET /api/cultivation-batches/{id}/harvests | 200 `{data:[Harvest]}`; không page/limit |
| POST /api/cultivation-batches/{id}/harvests | JSON; 201 message/data record |

```json
{
  "totalYieldKg": 125.5,
  "qualityGrade": "Loại A",
  "harvestedAt": "2026-10-05T02:00:00.000Z",
  "notes": "Đợt thu hoạch đầu",
  "finalizeBatch": false
}
```

Record có `id,batchId,totalYieldKg,qualityGrade,harvestedAt,notes,createdAt,createdByUserId,updatedByUserId`; hiện không có updatedAt. Bỏ harvestedAt thì backend dùng hiện tại. Không gửi actualYieldKg/amount/revenue hoặc batchId trong body. Không có sửa/xóa harvest trong phạm vi app.

Sau POST: tải lại harvest list, chi tiết lô và tài chính nếu đã tải; summary sản lượng/chi phí mỗi kg phải thay đổi theo server. Doanh thu chỉ xuất hiện khi ghi **lần bán**, không lấy kg × giá mặc định.

Từ công việc dùng record ID server làm `HARVEST` evidence. Gửi/duyệt task không tự finalize lô; thao tác finalize thuộc form thu hoạch.

## Kiểm tra

- [ ] Số âm bị chặn, 0 hợp lệ, số thập phân/dấu phẩy chuẩn hóa thành JSON number.
- [ ] finalize=false không tự đóng lô; finalize=true cập nhật lô theo server.
- [ ] Summary tài chính refresh, doanh thu không tự tăng khi chỉ thu hoạch.
- [ ] Evidence HARVEST dùng đúng record ID.
