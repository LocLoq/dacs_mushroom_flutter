# 00 — Overview

## Project

- Name (pubspec): `thu` | Display: Quản lý Sản xuất Nấm (Mushroom Production Management)
- Type: Flutter mobile/desktop/web app (multi-platform: android, ios, linux, macos, web, windows all scaffolded)
- SDK: Dart `>=3.11.4 <4.0.0`
- Entry point: `lib/main.dart` → `MushroomApp` (`lib/app/app.dart`) → `HomeScreen` (`lib/app/home_screen.dart`) hoặc `LoginScreen`

## Current state — READ BEFORE EDITING

- **Hệ thống kết hợp:** Quản lý sản xuất trại nấm (Facility, Strain, Account) và Hệ thống Nhận diện Nấm thông minh qua AI (AI Mushroom Recognition, Catalog, History, Settings).
- **Phân quyền truy cập:**
  - **Tính năng công khai (KHÔNG CẦN ĐĂNG NHẬP):** `Nhận diện AI` (Mushroom Recognition) và `Từ điển nấm` (Mushroom Catalog). Bất kỳ ai mở app cũng có thể chụp ảnh/quay video nhận diện hoặc tra cứu nấm độc/nấm ăn được.
  - **Tính năng quản trị (CẦN ĐĂNG NHẬP):** `Trại nấm` (Facility), `Giống nấm` (Strain), `Tài khoản` (Account).
- **Backend & Network:**
  - REST API & Multipart Upload (`http`, `http_parser`).
  - Hàng đợi Realtime WebSocket (`web_socket_channel`) kết hợp cơ chế thăm dò dự phòng (Dual-Sync: WebSocket + 2s Polling fallback).
  - Hỗ trợ chế độ Demo/Mock in-memory khi chưa kết nối máy chủ backend.
- **Lưu trữ cục bộ:** `shared_preferences` lưu cấu hình và tối đa 200 lượt lịch sử nhận diện; `path_provider` quản lý thư mục media trên máy.
- **Xử lý Media:** `image_picker`, `video_player`, `video_thumbnail`, `image` (tính toán gradient sắc nét 2D và phơi sáng luma để chọn frame video tối ưu).

## HomeScreen navigation

`HomeScreen` là màn hình shell chính, sử dụng sidebar gồm 6 mục:

1. Nhận diện AI — công khai
2. Từ điển — công khai
3. Cơ sở — yêu cầu đăng nhập
4. Giống nấm — yêu cầu đăng nhập
5. Lô nuôi trồng — yêu cầu đăng nhập
6. Tài khoản — yêu cầu đăng nhập

`HomeScreen` hỗ trợ `initialIndex` để chọn màn hình mở mặc định.

## Tech stack

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  http: ^1.4.0
  http_parser: ^4.1.2
  web_socket_channel: ^3.0.3
  shared_preferences: ^2.5.3
  path_provider: ^2.1.4
  image_picker: ^1.1.2
  video_player: ^2.9.5
  video_thumbnail: ^0.5.3
  image: ^4.5.4
dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0
```

## Domain in one paragraph

Ứng dụng tích hợp quản lý sản xuất nấm tại các cơ sở nuôi trồng (`Facility`), giống nấm thương phẩm (`Strain` kèm dải nhiệt độ, độ ẩm, CO2), quản lý nhân sự (`Account` phân quyền admin/manager/staff) cùng với công cụ AI nhận diện nấm ăn được / nấm độc qua hình ảnh & video, tra cứu từ điển loài nấm (`Catalog`) và lưu trữ lịch sử nhận diện (`History`).

## How to navigate this spec set

| File                        | Content                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------- |
| `01-architecture.md`        | Cấu trúc thư mục, quy tắc phân tầng, import direction                                                     |
| `02-data-models.md`         | Toàn bộ mô hình dữ liệu (Facility, Strain, Account, QueueJob, PreparedFrame, Catalog, History, AppConfig) |
| `03-api-contracts.md`       | Hợp đồng API REST (Django & FastAPI) và giao thức WebSocket `/ws/queue`                                   |
| `04-feature-auth.md`        | Đăng nhập và phân quyền truy cập (Công khai vs Đăng nhập)                                                 |
| `05-feature-facility.md`    | Quản lý cơ sở sản xuất nấm                                                                                |
| `06-feature-strain.md`      | Quản lý giống nấm và thông số môi trường                                                                  |
| `07-feature-account.md`     | Quản lý tài khoản nhân sự và phân quyền                                                                   |
| `08-shared-core.md`         | Dịch vụ dùng chung (FrameSelector, BackendQueue, History, Preferences, Theme, Localization)               |
| `09-backend-todo.md`        | Tổng hợp danh sách endpoint Django & FastAPI cần kết nối                                                  |
| `10-feature-recognition.md` | Đặc tả chi tiết tính năng Nhận diện Nấm AI (Chụp/Quay, chấm điểm frame, Dual-Sync, Popup)                 |
| `11-feature-catalog.md`     | Đặc tả chi tiết tính năng Từ điển Nấm (Tra cứu, thống kê an toàn/độc hại)                                 |
| `12-feature-history.md`     | Đặc tả chi tiết tính năng Lịch sử Nhận diện (Lưu trữ 200 bản ghi, xem chi tiết kết quả)                   |
| `13-feature-settings.md`    | Đặc tả chi tiết Cài đặt hệ thống, kết nối Backend URL, WebSocket, Theme & Ngôn ngữ                        |
