# S21 — Cài đặt

**Vị trí:** tab **Cài đặt**; cũng mở được từ nhãn kết nối ở tab Quét. **Quyền:** công khai. [Quy tắc chung](UI_DESIGN_SPEC.md).

## Nội dung (từ trên xuống)

1. **Máy chủ AI** — thẻ trạng thái WebSocket (chấm xanh/đỏ), ô **Backend URL** của dịch vụ AI (mặc định `http://10.0.2.2:8000`), nút **Kết nối** (lưu URL rồi nối WebSocket, hiện thanh tiến trình khi đang nối), **Lưu URL**, **Ngắt kết nối** và **Ping** (hai nút sau chỉ bật khi đã kết nối). Dùng cho tab Quét ([S10](S10_CLASSIFIER.md)) và Từ điển ([S20](S20_AI_CATALOG.md)).
2. **API Trại nấm** — công tắc **Dùng dữ liệu mẫu** (mặc định **bật**, xem [MOCK_DATA](MOCK_DATA.md); đổi công tắc xóa phiên đăng nhập hiện tại), rồi ô **Địa chỉ API** của backend Node, có hậu tố `/api` (mặc định `http://10.0.2.2:8080/api`). Nút **Lưu và kiểm tra** lưu rồi gọi `GET /auth/me` **không kèm token**: bất kỳ phản hồi HTTP nào (kể cả 401) nghĩa là máy chủ kết nối được, lỗi mạng/timeout thì báo không kết nối. Nút **Chỉ lưu** không kiểm tra. Địa chỉ rỗng được thay bằng mặc định; dấu `/` cuối bị bỏ. Dùng cho mọi chức năng trong tab Quản lý ([API_CONTRACT](API_CONTRACT.md)).
3. **Giao diện** — công tắc **Chế độ tối** (áp dụng **ngay**, không cần mở lại app) và chọn **Ngôn ngữ** VI/EN.
4. **Nhật ký WebSocket** — khung nền tối cao 160 px liệt kê sự kiện kết nối của dịch vụ AI; rỗng thì ghi “Chưa có sự kiện nào”.
5. **Về ứng dụng** — khung cảnh báo vàng mô tả ứng dụng và lưu ý: không tự ý ăn hoặc chế biến nấm hoang dã dựa trên kết quả AI; kết quả chỉ để tham khảo và nghiên cứu.

Lần mở app đầu tiên có hộp thoại hỏi địa chỉ máy chủ AI (`FirstRunBackendDialog`).

## Lưu trữ

| Giá trị | Nơi lưu |
| --- | --- |
| Backend URL của dịch vụ AI, chế độ tối, ngôn ngữ | `AppPreferencesService` (SharedPreferences) |
| Địa chỉ API Trại nấm | `ApiConfig` (SharedPreferences, khóa `farm_api_base_url`) |
| Công tắc dữ liệu mẫu | `MockConfig` (SharedPreferences, khóa `farm_mock_mode`, mặc định bật) |
| Token đăng nhập | `LocalSession` (SharedPreferences, khóa `farm_token`; chưa mã hóa, xem [S01](S01_LOGIN.md)) |

Hai địa chỉ máy chủ **độc lập**: đổi địa chỉ AI không ảnh hưởng quản lý trại và ngược lại. Đổi địa chỉ API Trại nấm không tự đăng xuất; nếu máy chủ mới không nhận token thì phiên bị xóa theo quy tắc 401 chung.

## Kiểm tra

- [ ] Công tắc tối đổi giao diện ngay và còn nguyên sau khi mở lại app.
- [ ] “Lưu và kiểm tra” báo đúng khi máy chủ tắt, bật (kể cả khi chỉ trả 401) và khi nhập sai địa chỉ.
- [ ] Android emulator dùng `10.0.2.2`; thiết bị thật dùng IP LAN; không nhầm hai ô địa chỉ.
- [ ] Thiết bị mới có hai địa chỉ mặc định đúng như trên.
