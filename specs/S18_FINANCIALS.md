# S18 — Tài chính lô và báo cáo tài chính

**Quyền:** chỉ manager/admin. Staff không hiện tab/mục dữ liệu tài chính và **không gọi API tài chính**, kể cả request preload.

## 1. Tab tài chính của lô

Trong chi tiết lô, tab **Tài chính** lazy load. KPI sản lượng thu hoạch, kg đã bán, doanh thu, tổng chi, lời/lỗ, tỷ suất lợi nhuận, chi phí/kg và breakdown theo nhóm. Hai danh sách **Khoản chi**/**Lần bán** phân trang, thêm/sửa/xóa; xóa có xác nhận.

API đều Bearer, ID lô/entry integer:

| Method / path | Query / body | Response |
| --- | --- | --- |
| GET /api/cultivation-batches/{id}/financial-summary | Không ngày | 200 data toàn vòng đời |
| GET /api/cultivation-batches/{id}/expenses | page=1, limit=10, tối đa 50 | 200 data/pagination |
| POST /api/cultivation-batches/{id}/expenses | ExpenseInput JSON | 201 message/data |
| PATCH /api/cultivation-batches/{id}/expenses/{entryId} | Field thay đổi | 200 message/data |
| DELETE /api/cultivation-batches/{id}/expenses/{entryId} | Không body | 200 message |
| GET /api/cultivation-batches/{id}/sales | page=1, limit=10, tối đa 50 | 200 data/pagination |
| POST /api/cultivation-batches/{id}/sales | SaleInput JSON | 201 message/data |
| PATCH /api/cultivation-batches/{id}/sales/{entryId} | Field thay đổi | 200 message/data |
| DELETE /api/cultivation-batches/{id}/sales/{entryId} | Không body | 200 message |

## 2. Form, Decimal và payload

| Khoản chi | Kiểu / giới hạn |
| --- | --- |
| name | Chuỗi bắt buộc, trim 1–255 ký tự |
| category | MATERIAL vật tư / TOOL dụng cụ / FERTILIZER phân bón / OTHER khác |
| quantity | **String Decimal >0**, ≤3 chữ số thập phân, <1.000.000.000 |
| unit | Chuỗi bắt buộc, 1–50 ký tự |
| unitPrice | **String Decimal ≥0**, ≤2 chữ số thập phân, <10.000.000.000.000.000 |
| incurredAt | ISO UTC, app có ngày mặc định; bỏ khi tạo server dùng now |
| notes | String nullable, ≤10.000 ký tự |

Lần bán: `quantityKg` giống quantity; `unitPrice` cùng quy tắc; `soldAt` giống incurredAt; `buyer` nullable ≤255; `notes` nullable ≤10.000.

Chuẩn hóa dấu phẩy thập phân sang dấu chấm, giữ string khi gửi; không nhận dấu phân nhóm tiền, số mũ, âm. Quantity 0 bị chặn, unitPrice 0 hợp lệ. Không đưa string qua double để rồi chuyển lại: tiền lớn có thể mất chữ số.

```json
{
  "name": "Phân bón hữu cơ",
  "category": "FERTILIZER",
  "quantity": "12.125",
  "unit": "kg",
  "unitPrice": "25000.50",
  "incurredAt": "2026-10-05T01:00:00.000Z",
  "notes": "Bổ sung đợt 1"
}
```

```json
{
  "quantityKg": "20.125",
  "unitPrice": "55000.00",
  "soldAt": "2026-10-05T02:00:00.000Z",
  "buyer": "Khách hàng A",
  "notes": null
}
```

PATCH chỉ gửi field thực sự thay đổi; nullable notes/buyer gửi null để xóa. Không gửi `amount,id,batchId,createdByUserId,updatedByUserId,createdAt,updatedAt`. Server tính quantity × unitPrice, làm tròn HALF_UP tới 2 chữ số; amount cũng phải <10^16. Client không tự quyết định thành tiền.

Entry trả quantity/quantityKg/unitPrice/amount **strings**, actor/timestamp metadata server và các field form. Expense/sale không phải inventory và không bổ sung kiểm soát công nợ/thuế/khấu hao.

Danh sách khoản chi sắp incurredAt giảm dần rồi ID giảm dần; lần bán theo soldAt giảm dần rồi ID giảm dần. GET không có filter ngày ở tab lô: phân trang toàn bộ lịch sử lô, khác query báo cáo.

## 3. Summary và hiển thị

```json
{
  "data": {
    "batchId": 1,
    "currency": "VND",
    "totalHarvestKg": 100,
    "totalSoldKg": 20.125,
    "revenue": "1106875.00",
    "totalCost": "500000.00",
    "profit": "606875.00",
    "costsByCategory": {
      "MATERIAL": "200000.00",
      "TOOL": "0.00",
      "FERTILIZER": "300000.00",
      "OTHER": "0.00"
    },
    "profitMarginPercent": "54.83",
    "costPerHarvestKg": "5000.00"
  }
}
```

Doanh thu = tổng amount lần bán; tổng chi = tổng amount khoản chi; profit = revenue − totalCost. Margin = profit/revenue ×100, null khi revenue=0; chi phí/kg = totalCost/totalHarvestKg, null khi chưa có kg thu hoạch. TotalHarvestKg/totalSoldKg hiện là JSON number; các chỉ số tiền/tỷ lệ Decimal là string.

Profit âm hiển thị rõ **Lỗ** và màu cảnh báo; dương là Lời. Null hiển thị “Chưa có dữ liệu”, không 0%. Định dạng tiền VND giữ mọi chữ số; chỉ chuyển sang double ở tọa độ biểu đồ, không ở nhãn/KPI/export.

Sau tạo/sửa/xóa expense/sale: reload list tương ứng + summary. Sau ghi thu hoạch: reload lô/harvest + tài chính nếu tab đã tải. Không tự suy ra doanh thu từ sản lượng thu hoạch.

## 4. Báo cáo theo kỳ

Trong Báo cáo chọn nhóm **Tài chính**. Filter from/to, facilityId, mushroomId, status lô; groupBy day/month. Default ngày theo S12, page 1/limit 20, tối đa 100. Tổng, danh sách doanh thu–chi phí–lợi nhuận theo kỳ (dạng chữ, chưa có biểu đồ), danh sách lô dạng card phân trang và các KPI chi tiết.

| Method / path | Response |
| --- | --- |
| GET /api/reports/financial | `{data,summary,series,period,pagination}` |
| GET /api/reports/financial/export | format + filters, không page/limit; bytes, S13 |

Ví dụ `GET /api/reports/financial?from=2026-10-01&to=2026-10-05&groupBy=day&facilityId=1&page=1&limit=20`.

Đọc **đầy đủ năm field top-level**:

- `data`: row lô gồm batchId/batchCode/status/facility (tên)/mushroom (tên) và các field financial summary, series riêng theo lô.
- `summary`: cùng cấu trúc chỉ số summary, tính trên **toàn bộ tập lọc**, không cộng page hiện tại.
- `series`: `[{period,revenue:string,totalCost:string,profit:string}]` trên toàn bộ tập lọc.
- `period`: `{from,to,groupBy}` server đã chuẩn hóa.
- `pagination`: metadata riêng của data.

Doanh thu theo soldAt, chi phí theo incurredAt, thu hoạch theo harvestedAt trong kỳ. Khác report nuôi trồng, financial **không loại lô bắt đầu trước kỳ**; lô khớp filter có thể xuất hiện với số liệu 0 khi không phát sinh trong kỳ. Series nhóm UTC+7. Không tự nhóm lại ngày local.

Chi tiết row/biểu đồ dùng dữ liệu báo cáo theo kỳ, không thay bằng GET financial-summary toàn vòng đời. Bấm một dòng lô để mở chi tiết lô và xem số liệu toàn vòng đời; giao diện phải phân biệt hai ngữ cảnh. Export giữ bộ lọc và dùng server, xem [S13](S13_REPORT_EXPORT.md).

## Kiểm tra

- [ ] Staff không có financial request; manager/admin CRUD thành công và refresh summary.
- [ ] Chuỗi tiền lớn giữ nguyên chữ số; dấu phẩy chuẩn hóa; âm/quantity=0/precision sai bị chặn.
- [ ] UnitPrice=0 hợp lệ; server amount được dùng, PATCH không gửi metadata.
- [ ] Lỗ/giá trị null rõ; ghi harvest refresh chi phí/kg, không tự tạo doanh thu.
- [ ] Tổng/series không đổi khi đổi page; lô trước kỳ và biên UTC+7 đúng.
- [ ] Export financial đủ filter, không page/limit; data theo kỳ khác summary lô.
