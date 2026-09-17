# 11 — Feature: Mushroom Catalog

## 1. Tổng quan

- **Mục tiêu:** Cung cấp từ điển tra cứu các loài nấm trong bộ dữ liệu huấn luyện của AI, phân loại nấm ăn được / nấm độc và thống kê dữ liệu.
- **Tập tin liên quan:**
  - `lib/features/mushroom_catalog/presentation/mushroom_catalog_screen.dart`
  - `lib/features/mushroom_catalog/data/catalog_model.dart`
  - `lib/core/network/api_client.dart` (`fetchMushroomCatalog()`)

## 2. Quyền truy cập

- **Công khai:** Người dùng không cần tài khoản hay đăng nhập. Tính năng này được đưa trực tiếp lên thanh điều hướng chính `HomeScreen` để bất kỳ ai mở ứng dụng cũng có thể tra cứu ngay lập tức.

## Điều hướng từ HomeScreen

`MushroomCatalogScreen` là mục thứ hai trong sidebar của `HomeScreen`.

Tính năng được truy cập công khai và không yêu cầu đăng nhập.

## 3. Các thành phần giao diện chính

1. **Thẻ thống kê tổng quan (Stat Cards):**
   - Tổng số loài (`Total`): Tổng số loài nấm trong cơ sở dữ liệu.
   - Số loài an toàn (`Safe`): Màu xanh lá.
   - Số loài có độc (`Poisonous`): Màu đỏ cảnh báo.
   - Nguồn dữ liệu (`Source`): Tên bộ dữ liệu (ví dụ: `mushroom_dataset_v1`).
2. **Thanh tìm kiếm (Search Bar):**
   - Tìm kiếm theo tên thông dụng tiếng Việt hoặc tên khoa học quốc tế.
3. **Danh sách loài nấm (ListView with Pull-to-Refresh):**
   - Hỗ trợ kéo xuống để làm mới dữ liệu (`RefreshIndicator`).
   - Mỗi item hiển thị:
     - Tên nấm thông dụng (in đậm).
     - Tên khoa học dạng chữ nghiêng (`scientificName`).
     - Badge phân loại rõ rệt: Màu đỏ mờ với icon cảnh báo cho nấm độc (`isPoisonous == true`), màu xanh mờ với icon chiếc lá cho nấm an toàn.
4. **Hộp thoại thông tin chi tiết:**
   - Chạm vào một loài nấm sẽ mở modal hiển thị đầy đủ tên, tên khoa học, khuyến cáo an toàn sinh học.

## 4. Dữ liệu mẫu Offline (Mock Data)

- Khi máy chủ FastAPI chưa bật hoặc thiết bị chưa có kết nối Internet, `ApiClient.fetchMushroomCatalog()` tự động fallback trả về `mockCatalog` tích hợp sẵn trong `catalog_model.dart` chứa 54 loài nấm (34 an toàn, 20 độc), đảm bảo ứng dụng luôn hiển thị dữ liệu đầy đủ.
