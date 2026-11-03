# S12 — Báo cáo

**Vị trí:** Quản lý → Báo cáo. **Quyền:** manager/admin. Staff không gọi API báo cáo.

## Giao diện và bộ lọc

Năm ChoiceChip: **Tổng quan**, **Nuôi trồng**, **Tài chính**, **Nhận diện**, **Hoạt động**. Tài chính chi tiết ở [S18](S18_FINANCIALS.md). Biểu tượng tải xuống trên AppBar mở [S13](S13_REPORT_EXPORT.md); bị khóa khi khoảng ngày không hợp lệ.

| Nhóm | Filter UI gửi |
| --- | --- |
| Tất cả | from, to; mặc định 01/01 năm hiện tại đến hôm nay |
| Tổng quan / Nuôi trồng / Tài chính | facilityId, mushroomId, status lô |
| Tổng quan / Tài chính | groupBy=day hoặc month, mặc định month |
| Nhận diện / Hoạt động | Chỉ from/to, ngoài page/limit cho list |

Facility/mushroom chọn bằng picker GET catalog. Status dùng enum **lô**, không phải QUEUED/SUCCEEDED hoặc SUCCESS/FAILURE. Chuyển nhóm giữ filter tương thích, reset page 1 và bỏ filter không dùng; bộ lọc dùng chung được giữ khi đổi nhóm; vị trí cuộn không được giữ.

Ngày là YYYY-MM-DD; from ≤ to, tối đa 5 × 366 ngày. Server đổi từ đầu/cuối ngày UTC+7. Biểu đồ dùng period server trả, null hiển thị “Chưa có dữ liệu”. Giao diện không dùng thư viện biểu đồ: số liệu theo kỳ hiển thị bằng thanh ngang kèm giá trị chữ nên luôn đọc được khi cỡ chữ lớn.

## API call

| Method / path | Response |
| --- | --- |
| GET /api/reports/overview | 200 `{data:Overview}` |
| GET /api/reports/cultivation | 200 data/pagination |
| GET /api/reports/classifier | 200 data/pagination |
| GET /api/reports/audit | 200 data/pagination |
| GET /api/reports/financial | 200 data/summary/series/period/pagination; S18 |

App dùng page 1, limit 20 cho bảng, backend tối đa 100. Tổng quan không cần cộng các trang bảng để dựng KPI. Ví dụ:

```text
GET /api/reports/cultivation?from=2026-10-01&to=2026-10-05&facilityId=1&mushroomId=2&status=HARVESTING&page=1&limit=20
GET /api/reports/overview?from=2026-10-01&to=2026-10-05&groupBy=day
GET /api/reports/classifier?from=2026-10-01&to=2026-10-05&page=1&limit=20
```

## Dữ liệu tổng quan

Overview có:

- `period:{from,to,groupBy}`.
- `cultivation:{facilities,species,batchCount,statusBreakdown,overdueBatches,totalHarvestKg,harvestSeries}`.
- `classifier:{total,succeeded,failed,averageConfidence,topPredictions,series}`.
- `audit:{totalActions,failedActions,actions,series}`.

`statusBreakdown` là object theo enum: `{"HARVESTING":{"count":3,"averageDefectRate":1.5}}`; không phải array. `harvestSeries` có `{period,count,totalYieldKg}`. Các series classifier/audit cũng có period/count (có thể kèm totalYieldKg không dùng). TopPredictions có name/count; actions có action/count.

UI tổng quan: bốn KPI batchCount/totalHarvestKg/classifier.total/audit.totalActions; thanh số liệu theo kỳ cho sản lượng kg, lượt nhận diện và hành động; phần số liệu mở rộng có thành công/thất bại, averageConfidence (%), audit failure và breakdown. Filter cơ sở/giống/status **chỉ tác động phần nuôi trồng**; classifier/audit vẫn theo ngày, UI ghi rõ.

Series overview hiện dùng ngày/tháng **UTC**; financial dùng **UTC+7**. Không tự đổi tên period hoặc cộng lại theo local.

## Dữ liệu bảng và ý nghĩa thời gian

Trên giao diện hiện tại mỗi dòng của “bảng” hiển thị dưới dạng card có phân trang Trước/Sau; ý nghĩa field không đổi.

| Bảng | Row fields |
| --- | --- |
| Nuôi trồng | batchCode, facility (tên), province, mushroom (tên), scientificName, status, startDate, expectedHarvestDate, endDate, defectRate, totalHarvestKg, latestGrowthStage, latestGrowthRecordedAt |
| Nhận diện | id UUID, originalName, status, predictedName, edibility, confidence, errorMessage, createdAt, completedAt, user |
| Hoạt động | actorUsername, actorRole, action, entityType, entityId, method, path, statusCode, outcome, durationMs, createdAt |

Nuôi trồng chọn các lô có **startDate nằm trong kỳ** và filter lô tương ứng; totalHarvestKg chỉ tính bản ghi harvestedAt trong kỳ. LatestGrowth là snapshot mới nhất của lô, không giới hạn trong kỳ. Row nuôi trồng hiện không có batchId: không lấy batchCode làm integer ID để mở chi tiết.

Classifier/audit theo createdAt trong kỳ; classifier user chứa username. Trong overview, batchCount/statusBreakdown chọn lô theo startDate trong kỳ, nhưng totalHarvestKg/harvestSeries chọn harvest trong kỳ theo cơ sở/giống/status, **không yêu cầu lô bắt đầu trong kỳ**. Vì vậy tổng kg overview có thể khác tổng các dòng báo cáo nuôi trồng. OverdueBatches so expectedHarvestDate với thời điểm hiện tại trên tập lô đã lọc và chưa kết thúc; không phải mốc to của báo cáo. Không thay sản lượng theo kỳ bằng actualYieldKg toàn vòng đời.

Tài chính khác: tập lô lọc không bị loại vì startDate trước kỳ; doanh thu/chi phí/thu hoạch trong kỳ, xem S18. Xuất giữ chính bộ lọc đang xem.

## Kiểm tra

- [ ] Đổi nhóm giữ đúng filter, không gửi classifier-status vào filter batch.
- [ ] Ngày biên UTC+7 và giới hạn khoảng ngày đúng; dữ liệu sát 00:00 không lệch kỳ.
- [ ] Overview dùng aggregates server, bảng dùng pagination server.
- [ ] Null/confidence/series rỗng có UI rõ; tiền tài chính không bị ép double.
- [ ] Không gán batchId giả từ batchCode trong report nuôi trồng.
