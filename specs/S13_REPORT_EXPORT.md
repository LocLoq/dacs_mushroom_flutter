# S13 — Xuất báo cáo

**Vị trí:** dialog từ màn Báo cáo, loại báo cáo cố định theo nhóm đang xem. **Quyền:** manager/admin.

## Giao diện và luồng

AlertDialog mọi nền tảng, nội dung cuộn: loại báo cáo, filter hiện tại (cơ sở/giống hiển thị bằng tên đã chọn, trạng thái lô bằng nhãn), chọn CSV/XLSX/PDF (mặc định XLSX), nút Tải xuống.

Giữ nguyên filter của trang khi mở/đóng. Khóa đổi định dạng/nút/đóng khi đang tải và lưu. Thành công hiện **đường dẫn file đã lưu** ngay trong dialog. **Bản này chưa có nút Mở/Chia sẻ:** trên Android file nằm ở thư mục ngoài riêng của app (người dùng tìm bằng trình quản lý file hoặc kết nối USB). Lỗi tải/ghi file giữ dialog và hiện thông báo.

## API call

| Method / path | Query / response |
| --- | --- |
| GET /api/reports/{type}/export | format + filter đang xem, **bỏ page và limit**; 200 bytes |

Type: `overview,cultivation,financial,classifier,audit`. Format: `csv,xlsx,pdf`. Filter được hỗ trợ từ màn báo cáo: `from,to,facilityId,mushroomId,status,groupBy`; chỉ gửi các filter hiện có cho loại đang xem.

Ví dụ:

```text
GET /api/reports/financial/export?format=xlsx&from=2026-10-01&to=2026-10-05&facilityId=1&mushroomId=2&status=HARVESTING&groupBy=month
Authorization: Bearer <token>
```

Không gửi JSON body, không xuất riêng page hiện tại và không dựng CSV/PDF giả phía client. Báo cáo financial lấy dữ liệu theo kỳ, khác summary toàn vòng đời trong tab lô.

| Format | Content-Type |
| --- | --- |
| CSV | text/csv; charset=utf-8 |
| XLSX | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet |
| PDF | application/pdf |

Server trả `Content-Disposition: attachment; filename="financial-report-YYYY-MM-DD.xlsx"`. Client ưu tiên filename* UTF-8 nếu có, rồi filename, rồi fallback type-report-ngàyUTC.format. Lọc ký tự đường dẫn/control khỏi tên file trước lưu.

Server hiện giới hạn **PDF 2.000 dòng, CSV/XLSX 50.000 dòng**; vượt trả 422. Thông báo “Báo cáo quá lớn. Vui lòng thu hẹp khoảng ngày hoặc bộ lọc.” Định dạng/type/query sai trả 400; auth theo contract chung.

## Tải file và nền tảng

Đọc response dưới dạng bytes. Bytes rỗng hoặc MIME JSON/HTML là lỗi, không lưu thành file báo cáo. HTTP lỗi trả JSON bytes vẫn cần giải mã message/code để xử lý phiên.

App ghi file bằng `path_provider` và `dart:io`: Android → `getExternalStorageDirectory()`; Windows/Linux/macOS → `getDownloadsDirectory()`; iOS hoặc khi không lấy được thư mục → thư mục Documents của app. Tên file lấy từ `filename*`/`filename` của server, ký tự cấm (`\ / : * ? " < > |` và ký tự điều khiển) thay bằng `_`; thiếu tên thì dùng `{loại}-report-{ngày}.{định dạng}`. **Chưa hỗ trợ web** (ghi file dùng `dart:io`). Không hứa một thư mục Downloads cố định cho mọi nền tảng. Mở/chia sẻ file (OpenFilex, share) nên bổ sung khi phát hành. Ở chế độ dữ liệu mẫu ([MOCK_DATA](MOCK_DATA.md)) file luôn là CSV, kể cả khi chọn XLSX/PDF, để thử luồng tải/lưu.

## Kiểm tra

- [ ] Xuất đủ năm loại, ba định dạng; file có nội dung thật, MIME và tên đúng.
- [ ] Request giữ filter nhưng không page/limit; nhiều trang không làm mất dòng.
- [ ] 422/401/403/JSON bytes không bị lưu thành .xlsx giả.
- [ ] Vietnamese filename, tên có ký tự lạ và filename* được xử lý.
- [ ] Nhấn đôi không tải hai lần; lỗi ghi file không crash; đóng dialog giữ query; đường dẫn hiển thị trỏ tới file có thật.
