# 02 — Data Models

All models are plain Dart classes (no `fromJson`/`toJson` yet — every `factory .fromJson(...)` is a commented-out stub). All are located in `features/*/data/*.dart`.

## FacilityModel — `lib/features/facility/data/facility_model.dart`
```dart
enum FacilityStatus { active, paused, maintenance }

class FacilityModel {
  final String id;
  final String name;
  final String address;
  final FacilityStatus status;
}
```
- All fields `final` and `required` (named constructor params). No mutable fields.
- `mockFacilities`: 3 hardcoded entries (`Trại nấm Đơn Dương` / active, `Trại nấm Đức Trọng` / maintenance, `Trại nấm Lạc Dương` / paused), all in Lâm Đồng province.
- No `fromJson` implemented — commented template only, expects backend to send `status` as the raw enum name string (`FacilityStatus.values.byName(json['status'])`).

## StrainModel — `lib/features/mushroom_strain/data/strain_model.dart`
```dart
class StrainModel {
  final String id;
  final String name;
  final double tempMin, tempMax;      // °C
  final double humidityMin, humidityMax; // %
  final double co2Min, co2Max;        // ppm
}
```
- All fields `final` and `required`.
- `mockStrains`: 3 entries — Nấm Bào Ngư, Nấm Linh Chi, Nấm Rơm — each with distinct temp/humidity/CO2 ranges.
- No `fromJson`/`toJson` implemented yet (both are TODO comments).
- No server-assigned ID scheme defined. Client currently generates a temporary id via `DateTime.now().millisecondsSinceEpoch.toString()` when creating new strains (see `strain_form_sheet.dart`) — **this must be replaced** once backend assigns real IDs; do not keep this ID-generation logic once `saveStrain` returns a server response.

## AccountModel — `lib/features/account/data/account_model.dart`
```dart
enum AccountRole { admin, manager, staff }

class AccountModel {
  final String id;
  final String fullName;
  final AccountRole role;
  final String assignedFacility;   // currently a free-text facility NAME, not a FacilityModel.id — see gap below
  bool isActive;                    // mutable — toggled by lock/unlock switch
  bool mustChangePassword;          // mutable — default false, set true when admin forces password reset
}
```
- `isActive` and `mustChangePassword` are the **only** mutable fields. `id`, `fullName`, `role`, `assignedFacility` are `final`.
- **Consequence for future edits:** to "change" `role` or `assignedFacility`, code must construct a brand-new `AccountModel` and replace it at its index in the list (`_accounts[_accounts.indexOf(a)] = AccountModel(...)`) — see `account_list_screen.dart` `onSaveRole` callback. Do not attempt `a.role = x`; it will not compile.
- `mockAccounts`: 3 entries — Nguyễn Văn A (admin, active), Trần Thị B (manager, active), Lê Văn C (staff, inactive). All `mustChangePassword: false` (default).
- **Known data-model gap:** `assignedFacility` is a raw `String` (facility display name), not a foreign key to `FacilityModel.id`. If facility names change, this field goes stale. Recommend backend use a `facility_id` and have the client resolve the display name via the already-loaded facility list.

## Auth "model" — no dedicated file (gap)
`ApiClient.login()` returns a raw `Map<String, dynamic>` shaped like:
```json
{ "access": "string (JWT)", "user": { "username": "string", "role": "string" } }
```
There is no `UserModel`/`AuthModel` class. `LocalSession.save(token, user)` (see `08-shared-core.md`) stores this map as-is. **If asked to add typed auth models, create `lib/features/auth/data/auth_model.dart`** following the same pattern as the other three models (final fields, named required constructor, no logic).

## Cross-model relationships (implicit, not enforced in code)
- `AccountModel.assignedFacility` semantically references a `FacilityModel` (by name, not id — see gap above).
- No model currently references `StrainModel` from `FacilityModel` (e.g. "which strains are grown at this facility" is not modeled). If a future task requires this, it is a new field, not present today.

---

# AI Recognition & Extended Models

## JobStatus — `lib/features/recognition/data/job_status.dart`
```dart
enum JobStatus { queued, processing, completed, failed }
```
- `queued`: Công việc đang nằm trong hàng đợi chờ xử lý. Màu: Hổ phách (`Colors.amber.shade800`).
- `processing`: Máy chủ đang chạy suy luận. Màu: Xanh dương (`Colors.blue.shade700`).
- `completed`: Hoàn tất và có kết quả. Màu: Xanh lá (`Colors.green.shade700`).
- `failed`: Thất bại hoặc job không tồn tại. Màu: Đỏ (`Colors.red.shade700`).

## PreparedFrame — `lib/features/recognition/data/prepared_frame.dart`
```dart
class PreparedFrame {
  final Uint8List bytes;
  final String sourcePath;
  final String sourceLabel;
  final String mediaType; // 'image' | 'video'
  final double qualityScore; // 0.0 -> 1.0
  final int? selectedFrameMs;
}
```

## QueueJob — `lib/features/recognition/data/queue_job.dart`
```dart
class QueueJob {
  final String jobId;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? result;
  final String? error;
  final Uint8List? previewBytes;
  final String? originalMediaPath;
  final String? originalMediaType;
  final Map<String, dynamic> imageInfo;
}
```

## QueueEvent — `lib/features/recognition/data/queue_event.dart`
```dart
class QueueEvent {
  final String event;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}
```

## RecognitionHistoryItem — `lib/features/recognition_history/data/history_item.dart`
```dart
class RecognitionHistoryItem {
  final String id;
  final String jobId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String backendBaseUrl;
  final String? mushroomName;
  final String? prediction;
  final String? rawPrediction;
  final double? confidence;
  final bool? isPoisonous;
  final String? decisionReason;
  final String? previewImagePath;
  final String? sourceMediaPath;
  final String? sourceMediaType;
  final Map<String, dynamic>? result;
  final String? error;
}
```
- Hỗ trợ `toJson()` và `fromJson()` an toàn (safe parsing: boolean, double, string null checks).
- Lưu trữ trong `SharedPreferences` dưới key `recognition_history_v1` (tối đa 200 bản ghi).

## MushroomCatalogResponse & MushroomCatalogItem — `lib/features/mushroom_catalog/data/catalog_model.dart`
```dart
class MushroomCatalogResponse {
  final String source;
  final int total;
  final int poisonousCount;
  final int safeCount;
  final List<MushroomCatalogItem> mushrooms;
  final List<MushroomCatalogItem> poisonousMushrooms;
}

class MushroomCatalogItem {
  final String name;
  final String scientificName;
  final bool isPoisonous;
}
```
- Cung cấp sẵn `mockCatalog` chứa 54 loài nấm (gồm các loài phổ biến: Nấm Rơm, Nấm Bào Ngư, Nấm Linh Chi, Nấm Mèo, Nấm Độc Tán Trắng, Nấm Tử Thần Amanita phalloides...) để app chạy offline mượt mà khi chưa kết nối backend.

## AppConfig — `lib/core/models/app_config.dart`
```dart
class AppConfig {
  final String backendBaseUrl;
  final bool darkMode;
  final String languageCode;
  final bool backendConfigured;
}
```

