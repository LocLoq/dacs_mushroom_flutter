# S16 — Tra cứu tiến trình công khai

**Vị trí:** màn Tra cứu tiến trình lô, mở từ màn Đăng nhập, từ tab Quản lý (thẻ dành cho khách; mục “Tra cứu công khai” khi đã đăng nhập) hoặc nút “Trang công khai” trong chi tiết lô. Không có URL riêng. **Quyền:** công khai; luôn bỏ Authorization.

## Giao diện và hành vi

Ô mã lô, nút tra cứu/Enter (không có liên kết sang nhận diện). Mã trim, dài 1–191 ký tự, encode khi đưa vào path. Mở từ chi tiết lô thì mã được điền sẵn và tự tra lần đầu. Khi sửa input bỏ kết quả cũ, bỏ qua response của lượt tìm trước đến muộn.

Ban đầu chưa tra khác với không thấy lô (404), lỗi mạng và lô chưa có nhật ký (currentProgress null). Kết quả hiện mã/trạng thái/ngày, tên giống, tên cơ sở/tỉnh, stage/notes/thời điểm hiện tại và ảnh xem/phóng to. App không có QR scanner hoặc nút chia sẻ riêng ở màn này.

## API call

| Method / path | Response |
| --- | --- |
| GET /api/public/cultivation-batches/{batchCode}/growth-progress/current | 200 data whitelist; 404 lô không tồn tại |

Không query page/limit. Ví dụ:

```json
{
  "data": {
    "batchCode": "LO-2026-001",
    "status": "FRUITING",
    "startDate": "2026-10-01T00:00:00.000Z",
    "expectedHarvestDate": null,
    "mushroom": {
      "commonName": "Nấm bào ngư",
      "scientificName": "Pleurotus ostreatus",
      "imageUrl": null
    },
    "facility": {"name": "Trại A", "province": "Đồng Nai"},
    "currentProgress": {
      "stage": "Ra quả thể",
      "notes": "Phát triển đều",
      "recordedAt": "2026-10-05T01:00:00.000Z",
      "updatedAt": "2026-10-05T01:00:00.000Z",
      "images": [{"imageUrl": "/uploads/growth-progress/example.jpg"}]
    }
  }
}
```

Đây là **whitelist công khai**, không dùng DTO chi tiết lô nội bộ để đòi ID/quan hệ đầy đủ. Không trả nhân viên, liên hệ nội bộ, toàn bộ nhật ký, chi phí/doanh thu hoặc submissions.

Server chọn record mới nhất có `recordedAt ≤ now`, thứ tự recordedAt giảm dần rồi ID giảm dần. Record tương lai không là currentProgress. Ảnh là ảnh growth record, không phải gallery lô. URL ảnh ghép với origin.

## Kiểm tra

- [ ] Token đang lưu cũng không gắn vào request công khai.
- [ ] Code có ký tự đặc biệt encode đúng; trống/quá dài không gọi.
- [ ] currentProgress null khác 404/lỗi; ngày tương lai không được coi hiện tại.
- [ ] Chỉ render whitelist; response cũ không ghi đè lần tra mới; ảnh lỗi có placeholder.
