# S10 — Nhận diện nấm (tab Quét)

**Vị trí:** tab **Quét** (tab mặc định). **Quyền:** công khai, không cần đăng nhập và **không gắn header Authorization**. Khác với các màn quản lý, tab này gọi trực tiếp **dịch vụ AI FastAPI** (địa chỉ cấu hình ở [S21](S21_SETTINGS.md), mặc định `http://10.0.2.2:8000`), không đi qua API Node. [API chung](API_CONTRACT.md).

## 1. Giao diện

Từ trên xuống:

1. **Tiêu đề** “Nhận diện nấm” và nhãn kết nối Trực tuyến/Ngoại tuyến (chấm xanh/đỏ, theo trạng thái WebSocket); bấm nhãn mở Cài đặt, giữ lâu hiện URL.
2. **Thẻ chào** nền gradient xanh, hình nấm vẽ sẵn và ba nút: **Chụp ảnh**, **Thư viện**, **Video**. Các nút khóa khi đang xử lý ảnh.
3. **Ba ô thống kê phiên**: Đang chờ, Hoàn tất, Tổng phiên này.
4. **Trạng thái chuẩn bị**: đang xử lý và chấm điểm độ sắc nét khung hình; lỗi chuẩn bị hiện khung đỏ.
5. **Thẻ ảnh đã chuẩn bị**: ảnh xem trước, nguồn và dung lượng, **thanh chất lượng ảnh** (dưới 50% hiện cảnh báo ảnh mờ/thiếu sáng), nút đóng và nút **Phân tích bằng AI** (khóa khi đang gửi).
6. **Kết quả gần đây**: mỗi lượt là một thẻ gồm ảnh nhỏ, mã job rút gọn, giờ, chip trạng thái và (khi hoàn tất) khối kết quả bên dưới. Rỗng thì có hướng dẫn chụp ảnh.
7. **Nhật ký kết nối** gập gọn (5 sự kiện gần nhất).

Nguồn ảnh: máy ảnh, thư viện, hoặc **video**. Với video, app chọn khung hình sắc nét nhất làm ảnh đầu vào (`FrameSelectorService`, tối đa rộng 720 px). Một lượt gửi là **một ảnh**. Rời tab không hủy job trên server (tab được giữ sống).

### Khối kết quả

Mỗi kết quả hoàn tất hiển thị: khối kết luận có màu (**Nấm an toàn/ăn được**, **Cảnh báo: nấm độc**, hoặc **Chưa rõ loài**), tên loài, **vòng tròn độ tin cậy %**, dòng giải thích đạt/dưới ngưỡng (mặc định 70%; dưới ngưỡng nhắc chụp lại rõ hơn). Mục “Chi tiết kỹ thuật” gập gọn: dự đoán gốc, ngưỡng, độ tin cậy, lý do quyết định, thời gian suy luận, dung lượng ảnh, SHA-256 rút gọn. Popup kết quả (và chi tiết lịch sử) thêm ảnh đầu, nhãn “Kết quả từ AI” và khung **lưu ý an toàn**: không tự ý ăn hoặc chế biến nấm hoang dã dựa trên dự đoán. `accepted_prediction:false` hiện chưa đạt ngưỡng; không dùng nhãn dự đoán làm kết luận chắc chắn.

## 2. Dịch vụ AI (FastAPI) mà bản này gọi

| Method / path | Chi tiết | Ghi chú |
| --- | --- | --- |
| POST `{base}/api/images/upload` | Multipart, field **`file`**, đúng một ảnh, tên `upload-{timestamp}.{ext}`; timeout 10 giây | 200/201 `{job_id}`; mã khác là lỗi |
| GET `{base}/api/jobs/{job_id}` | Gọi ngay sau upload, rồi **polling mỗi 2 giây** khi job còn queued/processing; timeout 4 giây | Cập nhật trạng thái/kết quả |
| WebSocket `ws(s)://{host}/ws/queue` | Tự kết nối khi mở tab, **tự nối lại sau 2 giây** khi rớt | Sự kiện bên dưới |

Sự kiện WebSocket có dạng `{ "event"|"type": "job.status"|"job.result", "data": { "job_id", "status", "result"?, "error"? } }`. Trạng thái dùng chữ thường: `queued`, `processing` (cũng nhận `running`), `completed` (cũng nhận `success`, `done`), `failed` (cũng nhận `error`). Khi hoàn tất hoặc thất bại, lượt quét được lưu vào lịch sử trên máy ([S11](S11_CLASSIFIER_HISTORY.md)). Tin nhắn `pong` được nhận như tín hiệu sống.

Các field của `result` mà giao diện sử dụng:

```json
{
  "prediction": "Pleurotus ostreatus",
  "mushroom_name": "Nấm Bào Ngư",
  "raw_prediction": "Pleurotus ostreatus",
  "accepted_prediction": true,
  "confidence": 0.92,
  "confidence_threshold": 0.70,
  "is_poisonous": false,
  "decision_reason": "…",
  "inference_time_seconds": 0.35,
  "size_bytes": 123456,
  "sha256": "…"
}
```

`confidence` và `confidence_threshold` chấp nhận thang 0–1 hoặc 0–100 (giá trị ≤1 được hiểu là tỉ lệ). `prediction = unknown` hoặc `is_poisonous` thiếu → hiện “Chưa rõ loài”. Không hiện stack trace cho người dùng.

## 3. Chế độ giả lập khi mất kết nối — rủi ro an toàn

Nếu upload thất bại (không kết nối được máy chủ AI, timeout, lỗi HTTP), `BackendQueueService.enqueue()` **tự chuyển sang giả lập**: sau ~0,6 giây “xử lý”, ~1,5 giây sau trả một kết quả **chọn ngẫu nhiên** trong bốn loài mẫu (Nấm Bào Ngư, Nấm Rơm, Nấm Tử Thần, Nấm Tán Bay) với độ tin cậy cố định 93,5%, `sha256 = simulated_offline_hash`, `decision_reason = "Demo / Offline Simulation Result"`.

Đây là hành vi **có từ phiên bản trước** của dịch vụ hàng đợi, phục vụ trình diễn. Vì kết quả không liên quan đến ảnh thật, giao diện **bắt buộc** hiển thị rõ, ở mọi nơi dùng chung khối kết quả (thẻ, popup, chi tiết lịch sử):

- nhãn **“KẾT QUẢ GIẢ LẬP (demo)”** thay cho kết luận an toàn/độc, màu cảnh báo;
- dòng chữ đỏ: *không kết nối được máy chủ AI nên đây là dữ liệu mẫu ngẫu nhiên, không phải nhận diện thật, không dùng để quyết định ăn nấm*.

Nhận biết kết quả giả lập bằng `sha256 == "simulated_offline_hash"` hoặc `decision_reason` chứa “Simulation”. Khi phát hành thật, nên **tắt hẳn** nhánh giả lập và hiện lỗi “Không kết nối được máy chủ AI” thay vì sinh kết quả.

## 4. API Node (tham chiếu, chưa nối trong UI này)

Backend Node có thêm đường nhận diện riêng mà giao diện này **chưa gọi**. Giữ lại làm tham chiếu để chuyển đổi sau này.

| Method / path | Body / auth | Response |
| --- | --- | --- |
| POST /api/mushroom-classifier/classify | Multipart field **image**, đúng 1 file; công khai bỏ Authorization, nội bộ Bearer | 202 `{jobId,status}` (UUID string) |

Socket.IO vào origin Node, path mặc định, transport websocket: client gửi `subscribe_job` với **chuỗi jobId** (không phải object) sau mỗi lần connect/reconnect; server gửi `processing`, `finished` (có `result`: `accepted`, `name`, `scientificName`, `edibility`, `confidence` 0–1), `failed`. Edibility của classifier là `POISONOUS`, `NON_POISONOUS`, `UNKNOWN`, khác enum catalog giống. Bản Node không dùng HTTP polling hay tự gửi lại POST. Backend không lưu ảnh đầu vào; lưu tên/MIME/kích thước/trạng thái/kết quả, được xem ở nhánh “Máy chủ” của [S11](S11_CLASSIFIER_HISTORY.md).

## Kiểm tra

- [ ] 0 hoặc nhiều ảnh trong một lượt không gửi; nút khóa khi đang chuẩn bị/gửi.
- [ ] Upload thành công trả `job_id`; trạng thái đi queued → processing → completed/failed qua WebSocket hoặc polling; không nhầm “đã nhận job” với “đã có kết quả”.
- [ ] Rớt WebSocket tự nối lại; polling vẫn cập nhật khi WebSocket rớt.
- [ ] Ảnh mờ có cảnh báo chất lượng; kết quả dưới ngưỡng, `unknown`, `failed` có giao diện rõ.
- [ ] **Tắt máy chủ AI: kết quả giả lập luôn có nhãn “KẾT QUẢ GIẢ LẬP” và dòng cảnh báo đỏ, không hiện “Nấm an toàn/Cảnh báo nấm độc”.**
- [ ] Độ tin cậy 0,92 hiện 92%; khung lưu ý an toàn luôn có ở popup.
