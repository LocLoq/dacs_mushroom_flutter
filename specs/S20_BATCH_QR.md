

# S20 — QR theo mã lô

QR chứa batchCode thuần. Chi tiết lô hiển thị QR với mã lô và lưu PNG nền trắng qua hộp thoại lưu file. Hủy lưu không báo thành công.

Bộ quét dùng chung cho khách và nhân viên; chỉ QR, trim mã dài 1–191 ký tự, chống xử lý lặp. Android/iOS/Web quét camera; desktop nhập mã. Camera bị từ chối/lỗi vẫn nhập mã được. Camera dừng khi rời màn và được giải phóng khi dispose. Web cần HTTPS/localhost.

Khách quét tại Tra cứu tiến trình lô rồi gọi API public hiện có, bỏ Authorization. Nhân viên quét từ Quản lý/danh sách lô, gọi GET /cultivation-batches/by-code/{batchCode} có token để nhận { data: { id, batchCode } }. Chọn Sinh trưởng/Chăm sóc/Thu hoạch để mở BatchDetailScreen với initialTab progress/care/harvest. Không tự POST khi quét. Guest không mở chức năng cập nhật; 401/404/lỗi mạng được hiển thị. Encode mã thành một path segment đúng một lần.
