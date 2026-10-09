# Contract tích hợp API

**Đối chiếu 05/10/2026.** Schema đầy đủ: [openapi.yaml](openapi.yaml). Hành vi gọi API theo màn: các liên kết bên dưới.

## 1. URL, transport và xác thực

Base URL có `/api`, ví dụ `http://127.0.0.1:8080/api`. Các bảng spec ghi path đầy đủ `/api/...`; nếu SDK dùng base URL này, gọi path tương đối `/login`, `/dashboard/tasks`… để tránh lặp `/api/api`.

Android emulator: `http://10.0.2.2:8080/api`; web/desktop: `http://127.0.0.1:8080/api`; thiết bị thật: IP LAN/hostname. Bản Flutter này lưu địa chỉ trong **Cài đặt → API Trại nấm** (SharedPreferences, mặc định `http://10.0.2.2:8080/api`), không dùng `API_BASE_URL` lúc build ([S21](S21_SETTINGS.md)). Các chức năng quản trị không gọi dịch vụ Python nhận diện; riêng tab **Quét** gọi trực tiếp dịch vụ AI FastAPI bằng địa chỉ cấu hình riêng ([S10](S10_CLASSIFIER.md)). Khi **chế độ dữ liệu mẫu** bật, mọi lệnh gọi trong tài liệu này được trả lời cục bộ và không có yêu cầu mạng nào ([MOCK_DATA](MOCK_DATA.md)).

JSON: `Accept: application/json`, `Content-Type: application/json`. API nội bộ: `Authorization: Bearer <token>`. Login, tra cứu công khai và classifier công khai **bỏ header Authorization**, kể cả khi client đang có phiên. Multipart để thư viện tự đặt boundary, không ép application/json.

HTTP timeout hiện tại: 45 giây cho toàn bộ một yêu cầu (package `http` không tách connect/receive), tải file báo cáo 2 phút; quá hạn hiện lỗi mạng và không tự gửi lại. Media dùng **origin của Node** (bỏ hậu tố /api). Bản này không dùng Socket.IO. URL ảnh `/uploads/...` ghép với origin; giữ URL http/https tuyệt đối, bỏ URL rỗng/scheme không hỗ trợ.

POST login trả token rồi client bắt buộc GET auth/me để lấy user/role; không đoán role bằng giải mã JWT. Token lưu trong SharedPreferences (xem [S01](S01_LOGIN.md)), khôi phục phiên cũng gọi auth/me. JWT backend hiện hết hạn sau 2 giờ; không có refresh token/logout endpoint. Đổi role/password làm token cũ mất hiệu lực.

## 2. Envelope và kiểu dữ liệu

Danh sách có phân trang:

```json
{
  "data": [],
  "pagination": {
    "totalItems": 0,
    "currentPage": 1,
    "totalPages": 0,
    "pageSize": 10
  }
}
```

Chi tiết: `{"data": {...}}`. Tạo/sửa thường `{"message":"...","data": {...}}`; xóa `{"message":"..."}`. Không suy luận mọi mutation có data: xem responses OpenAPI và từng màn. Care/growth/harvest/roles là `{"data": [...]}` **không pagination**. Financial report có năm field top-level riêng, không giải mã bằng page DTO làm mất summary/series/period.

| Loại | Quy tắc |
| --- | --- |
| Task, submission, classifier ID | UUID dạng string, không parse int |
| Batch, facility, mushroom, user, role, record, gallery, expense, sale ID | Integer dương |
| Expense.quantity, Sale.quantityKg, unitPrice, amount | Decimal dạng **string** |
| Revenue, totalCost, profit, costsByCategory, các tỷ lệ tài chính | String Decimal; chỉ số chưa xác định có thể null |
| totalHarvestKg / totalSoldKg của financial summary | JSON number theo backend hiện tại |
| Thu hoạch/diện tích/công suất/tỷ lệ lỗi legacy | JSON number; không áp dụng string Decimal của tài chính sang các form này |
| Timestamp | ISO 8601; server trả UTC, UI hiển thị local |
| Tên field | camelCase; User dùng full_name, phone_number, role_id; auth/me.role là string, admin/users.role là object |

Không gửi ID, amount tính sẵn, timestamp hệ thống, người tạo/cập nhật, cover/count hay object quan hệ trong body CRUD. Chỉ gửi allowlist của form. Số tiền hiển thị phải giữ độ chính xác; chỉ đổi số để vẽ tọa độ biểu đồ, không dùng số đó làm tiền hiển thị.

## 3. Query, phân trang và ngày

`page` bắt đầu 1, `limit` là số nguyên dương; bỏ filter null/rỗng. Đổi filter reset page 1. Server trả totalPages 0 khi rỗng; UI có thể ghi trang 1/1 nhưng không cho Next.

| Nhóm | Limit app / tối đa backend |
| --- | --- |
| Catalog, batches, tasks, assignees, candidates, users, expenses, sales, galleries | 10 / 50 |
| Dashboard batches/tasks | 5 / 50 |
| Classifier history, audit, báo cáo dạng bảng | 20 / 100 |
| Care/growth/harvest/roles | Không phân trang |

Reports: `from`, `to` dạng YYYY-MM-DD là đầu/cuối ngày **UTC+7**, khoảng tối đa 5 × 366 ngày, from ≤ to. Ví dụ `from=2026-10-01&to=2026-10-05` tương ứng 30/09 17:00Z đến 05/10 16:59:59.999Z. Timestamp ISO có timezone được hiểu là thời điểm tuyệt đối. Mặc định UI chọn 01/01 năm hiện tại tới ngày hôm nay. `groupBy=day|month`.

**Khác biệt hiện tại:** series báo cáo financial nhóm theo UTC+7; series overview cũ nhóm bằng ngày/tháng UTC. Client hiển thị khóa period server trả về, không tự gom lại theo timezone khác. Classifier history/audit dùng timestamp ISO từ đầu/cuối ngày local thiết bị, không tự áp dụng quy tắc YYYY-MM-DD của reports.

## 4. Lỗi và trạng thái phiên

Body lỗi thường `{"message":"...","code":"..."}`; code không bắt buộc.

| HTTP / code | Hành vi |
| --- | --- |
| 400, 422 validation | Hiện message, giữ form/query; export 422 báo vượt giới hạn |
| 401 | Xóa phiên nội bộ, chuyển login; không lặp mutation |
| 403 + AUTH_INVALID_TOKEN | Xóa phiên như token hết hiệu lực |
| 403 + AUTH_FORBIDDEN | Giữ phiên, thông báo không đủ quyền |
| 404 | Không tồn tại; GET auth/me có xử lý chờ xác nhận phiên ở S01 |
| 409 công việc | Tải lại task, thông báo trạng thái đã đổi; không tự gửi lại |
| 500, 503, mất mạng | Hiện lỗi/tải lại; auth/me có thể giữ token ở trạng thái chờ profile |

App còn nhận diện thông báo cũ “Token không hợp lệ hoặc đã hết hạn” như lỗi token. Response export là bytes: khi HTTP lỗi vẫn giải mã JSON lỗi để xử lý auth. Không log token/password hoặc đưa stack trace classifier lên UI.

## 5. Danh mục API call

“A” = admin, “M” = manager, “S” = staff. Quyền ở đây là quyền API; UI có thể hạn chế thêm theo trạng thái/người nhận.

| Method và path | Quyền / dữ liệu | Spec |
| --- | --- | --- |
| POST /api/login | Công khai; username/password → token | [S01](S01_LOGIN.md) |
| GET /api/auth/me | A/M/S; profile | [S01](S01_LOGIN.md) |
| GET /api/dashboard/tasks | A/M/S; paged + filters | [S02](S02_DASHBOARD.md), [S17](S17_TASK_EVIDENCE.md) |
| POST /api/dashboard/tasks | A/M; TaskCreateInput | [S17](S17_TASK_EVIDENCE.md) |
| GET /api/dashboard/tasks/{id} | A/M/S; task + submissions | [S17](S17_TASK_EVIDENCE.md) |
| PATCH, DELETE /api/dashboard/tasks/{id} | PATCH theo trạng thái/owner; DELETE A/M chưa có lịch sử | [S17](S17_TASK_EVIDENCE.md) |
| GET /api/dashboard/task-assignees | A/M; paged users | [S17](S17_TASK_EVIDENCE.md) |
| GET /api/dashboard/tasks/{id}/evidence-candidates | Người nhận; paged | [S17](S17_TASK_EVIDENCE.md) |
| POST /api/dashboard/tasks/{id}/submissions | Người nhận; TaskSubmissionInput | [S17](S17_TASK_EVIDENCE.md) |
| POST /api/dashboard/tasks/{id}/submissions/{submissionId}/review | A/M khác người gửi; TaskReviewInput | [S17](S17_TASK_EVIDENCE.md) |
| GET, POST /api/cultivation-batches | GET A/M/S; POST A/M | [S03](S03_BATCH_LIST.md) |
| GET, PUT, DELETE /api/cultivation-batches/{id} | GET/PUT A/M/S; DELETE A/M | [S04](S04_BATCH_DETAIL.md) |
| GET, POST /api/cultivation-batches/{id}/care-logs | A/M/S; array / JSON | [S05](S05_CARE_LOGS.md) |
| GET, POST /api/cultivation-batches/{id}/harvests | A/M/S; array / JSON | [S06](S06_HARVESTS.md) |
| GET, POST /api/cultivation-batches/{id}/growth-progress | A/M/S; array / multipart | [S07](S07_GROWTH_PROGRESS.md) |
| PATCH /api/cultivation-batches/{id}/growth-progress/{recordId} | A/M/S; multipart | [S07](S07_GROWTH_PROGRESS.md) |
| GET, POST /api/mushroom-species | GET A/M/S; POST A/M | [S08](S08_MUSHROOM_SPECIES.md) |
| GET, PUT, DELETE /api/mushroom-species/{id} | GET A/M/S; PUT/DELETE A/M | [S08](S08_MUSHROOM_SPECIES.md) |
| GET, POST /api/production-facilities | GET A/M/S; POST A/M | [S09](S09_FACILITIES.md) |
| GET, PUT, DELETE /api/production-facilities/{id} | GET A/M/S; PUT/DELETE A/M | [S09](S09_FACILITIES.md) |
| POST /api/mushroom-classifier/classify | Công khai hoặc A/M/S; multipart → 202. **Tham chiếu, UI này chưa gọi** | [S10](S10_CLASSIFIER.md) |
| GET /api/mushroom-classifier/history | A/M; paged | [S11](S11_CLASSIFIER_HISTORY.md) |
| GET /api/mushroom-classifier/history/{id} | A/M; detail | [S11](S11_CLASSIFIER_HISTORY.md) |
| GET /api/reports/overview | A/M; aggregates | [S12](S12_REPORTS.md) |
| GET /api/reports/cultivation | A/M; paged | [S12](S12_REPORTS.md) |
| GET /api/reports/classifier | A/M; paged | [S12](S12_REPORTS.md) |
| GET /api/reports/audit | A/M; paged | [S12](S12_REPORTS.md) |
| GET /api/reports/financial | A/M; data + summary + series + period + pagination | [S18](S18_FINANCIALS.md) |
| GET /api/reports/{type}/export | A/M; bytes, cùng filters, không page/limit | [S13](S13_REPORT_EXPORT.md) |
| GET, POST /api/admin/users | Admin; paged / JSON | [S14](S14_USERS.md) |
| PUT, DELETE /api/admin/users/{id} | Admin; JSON / message | [S14](S14_USERS.md) |
| GET /api/admin/roles | Admin; array | [S14](S14_USERS.md) |
| GET /api/admin/audit-logs | A/M; paged | [S15](S15_AUDIT_LOG.md) |
| GET /api/public/cultivation-batches/{batchCode}/growth-progress/current | Công khai; whitelist data | [S16](S16_PUBLIC_GROWTH.md) |
| GET /api/cultivation-batches/{id}/financial-summary | A/M; toàn vòng đời | [S18](S18_FINANCIALS.md) |
| GET, POST /api/cultivation-batches/{id}/expenses | A/M; paged / ExpenseInput | [S18](S18_FINANCIALS.md) |
| PATCH, DELETE /api/cultivation-batches/{id}/expenses/{entryId} | A/M; ExpenseUpdateInput / message | [S18](S18_FINANCIALS.md) |
| GET, POST /api/cultivation-batches/{id}/sales | A/M; paged / SaleInput | [S18](S18_FINANCIALS.md) |
| PATCH, DELETE /api/cultivation-batches/{id}/sales/{entryId} | A/M; SaleUpdateInput / message | [S18](S18_FINANCIALS.md) |
| GET, POST /api/production-facilities/{id}/images | GET A/M/S; POST A/M multipart | [S19](S19_ENTITY_GALLERY.md) |
| PATCH, DELETE /api/production-facilities/{id}/images/{imageId} | A/M; GalleryImageUpdateInput / message | [S19](S19_ENTITY_GALLERY.md) |
| GET, POST /api/mushroom-species/{id}/images | GET A/M/S; POST A/M multipart | [S19](S19_ENTITY_GALLERY.md) |
| PATCH, DELETE /api/mushroom-species/{id}/images/{imageId} | A/M; GalleryImageUpdateInput / message | [S19](S19_ENTITY_GALLERY.md) |
| GET, POST /api/cultivation-batches/{id}/images | GET A/M/S; POST A/M multipart | [S19](S19_ENTITY_GALLERY.md) |
| PATCH, DELETE /api/cultivation-batches/{id}/images/{imageId} | A/M; GalleryImageUpdateInput / message | [S19](S19_ENTITY_GALLERY.md) |

Nhận diện của bản này đi qua dịch vụ AI FastAPI (upload + WebSocket + polling), mô tả ở S10; endpoint classifier của Node chỉ để tham chiếu. Không có API CRUD role, GET user detail, GET audit detail, sửa/xóa care/harvest hoặc xóa riêng ảnh growth trong phạm vi app hiện tại.
