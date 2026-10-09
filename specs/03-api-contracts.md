# 03 — API Contracts (`lib/core/network/api_client.dart`)

`ApiClient` is a plain class (no interface/abstract base), instantiated directly (`final _api = ApiClient();`) in every screen's State — no dependency injection, no singleton. Every method today is a mock: `await Future.delayed(...)` then return static/dummy data. **Nothing here makes a real HTTP call.**

The file header contains a commented Dio+Interceptor template (JWT bearer header injection, 401 → logout handling) — this is the intended real implementation, not yet applied. When wiring a real backend, replace method bodies only; keep signatures identical so callers (`FacilityListScreen`, `StrainListScreen`, `AccountListScreen`, `LoginScreen`, `AccountEditSheet`) do not need changes.

## `login`
```dart
Future<Map<String, dynamic>> login(String username, String password)
```
- Mock: 600ms delay; throws `Exception('Sai tài khoản hoặc mật khẩu')` if either arg is empty; else returns `{'access': 'FAKE_JWT_TOKEN', 'user': {'username': username, 'role': 'Manager'}}`.
- Intended backend: `POST {baseUrl}/auth/login/` body `{username, password}` → `{access, refresh, user}`.
- Caller: `LoginScreen._handleLogin` — wraps in try/catch, on success calls `LocalSession.save(result['access'], result['user'])` then navigates to `HomeScreen`.

## `fetchFacilities`
```dart
Future<List<FacilityModel>> fetchFacilities()
```
- Mock: 400ms delay, returns `mockFacilities` unfiltered.
- Intended backend: `GET {baseUrl}/facilities/?search=&status=` — **note the mock does not implement search/status filtering server-side; filtering currently happens 100% client-side** in `FacilityListScreen._filtered` getter. Decide during backend work whether filtering moves server-side (recommended once facility count grows) or stays client-side.
- Caller: `FacilityListScreen._load`.

## `fetchStrains`
```dart
Future<List<StrainModel>> fetchStrains()
```
- Mock: 400ms delay, returns `mockStrains`.
- Intended backend: `GET {baseUrl}/strains/`.
- Caller: `StrainListScreen._load`.

## `saveStrain`
```dart
Future<void> saveStrain(StrainModel strain)
```
- Mock: 300ms delay, no-op, no return value, never throws.
- Intended backend: `POST {baseUrl}/strains/` (create) or `PUT {baseUrl}/strains/{id}/` (update) — **the mock does not distinguish create vs update**; caller must decide based on whether `strain.id` was client-generated (temporary) or server-issued. Real implementation should return the server-assigned `StrainModel` (with real `id`) so the temporary millisecond-based id can be discarded.
- Caller: `StrainListScreen._openForm` → `StrainFormSheet.onSave`.

## `fetchAccounts`
```dart
Future<List<AccountModel>> fetchAccounts()
```
- Mock: 400ms delay, returns `mockAccounts`.
- Intended backend: `GET {baseUrl}/accounts/`. **Permission requirement (from code comment): only Admin/Manager roles should be authorized to call this — enforce server-side, not just by hiding the UI tab.**
- Caller: `AccountListScreen._load`.

## `toggleAccountLock`
```dart
Future<void> toggleAccountLock(String id)
```
- Mock: 200ms delay, no-op.
- Intended backend: `PATCH {baseUrl}/accounts/{id}/` body `{"is_active": bool}`. Note: the mock signature does not receive the new boolean value — caller flips `a.isActive` locally after the call succeeds (optimistic-after-success, not before). If the real endpoint needs the target value sent explicitly, **this signature must change** to `toggleAccountLock(String id, bool newValue)`.
- Caller: `AccountListScreen._toggleLock`.

## `updateAccountRole`
```dart
Future<void> updateAccountRole(String id, AccountRole role, String facility)
```
- Mock: 300ms delay, no-op.
- Intended backend: `PATCH {baseUrl}/accounts/{id}/` body `{"role": "admin|manager|staff", "assigned_facility": id}`.
- **Security requirement from code comment: only Admin should be allowed to change another user's role — this must be enforced server-side (Django `permission_classes`), not merely by hiding the dropdown client-side.**
- Note: `facility` param is currently a free-text string (see model gap in `02-data-models.md`); backend contract shown here (`"assigned_facility": id`) assumes this will become an id — reconcile before implementing.
- Caller: `AccountEditSheet._submitRole` via `AccountListScreen._openEditSheet`'s `onSaveRole` callback.

## `setAccountPassword`
```dart
Future<void> setAccountPassword(String id, String newPassword, {required bool mustChangePassword})
```
- Mock: 300ms delay, no-op.
- Intended backend: `POST {baseUrl}/accounts/{id}/set-password/` body `{"new_password": "...", "must_change_password": true|false}`.
- **Security requirements from code comments:**
  1. There is intentionally no "get password" / "view password" endpoint anywhere in this contract — passwords are write-only from the client's perspective.
  2. Client-side validation (min 6 chars, confirm-match — see `AccountEditSheet._submitPassword`) is UX-only. **Backend must independently re-validate** password strength; never trust the client.
  3. `must_change_password: true` should set a persistent flag on the user record server-side (e.g. `user.must_change_password = True`), and auth middleware should block all other API calls for that user until they hit a **separate** "change my own password" endpoint (not this one — this one is for an admin resetting someone else's password without knowing their old one).
- Caller: `AccountEditSheet._submitPassword` via `AccountListScreen._openEditSheet`'s `onSavePassword` callback.

## Summary table

| Method | HTTP (intended) | Auth requirement | Real impl. changes signature? |
|---|---|---|---|
| `login` | `POST /auth/login/` | none (public) | no |
| `fetchFacilities` | `GET /facilities/` | logged in | maybe (add query params) |
| `fetchStrains` | `GET /strains/` | logged in | no |
| `saveStrain` | `POST` or `PUT /strains/(:id)/` | logged in | should return `StrainModel` |
| `fetchAccounts` | `GET /accounts/` | admin/manager only | no |
| `toggleAccountLock` | `PATCH /accounts/:id/` | admin/manager only | possibly (add bool param) |
| `updateAccountRole` | `PATCH /accounts/:id/` | **admin only** | maybe (facility id vs name) |
| `setAccountPassword` | `POST /accounts/:id/set-password/` | admin/manager only | no |
| `fetchMushroomCatalog` | `GET /api/mushrooms/catalog` | **public (no auth)** | no |
| `uploadImage` | `POST /api/images/upload` (Multipart) | **public (no auth)** | no |
| `fetchJob` | `GET /api/jobs/{job_id}` | **public (no auth)** | no |

---

# AI Recognition & Catalog Endpoints (FastAPI Backend)

## `GET /api/mushrooms/catalog`
- **Mục đích:** Tải danh mục loài nấm trong bộ dữ liệu huấn luyện, thống kê tỷ lệ nấm độc / nấm an toàn.
- **Xác thực:** Công khai (**Không cần đăng nhập**).
- **Caller:** `MushroomCatalogScreen._loadCatalog` / `ApiClient.fetchMushroomCatalog()`.
- **Response 200 OK:**
  ```json
  {
    "source": "mushroom_dataset_v1",
    "total": 54,
    "poisonous_count": 20,
    "safe_count": 34,
    "mushrooms": [
      { "name": "Agaricus bisporus", "scientific_name": "Agaricus bisporus", "is_poisonous": false },
      { "name": "Amanita phalloides", "scientific_name": "Amanita phalloides", "is_poisonous": true }
    ],
    "poisonous_mushrooms": [ ... ]
  }
  ```
- **Fallback khi offline:** Sử dụng dữ liệu `mockCatalog` có sẵn trong code.

## `POST /api/images/upload`
- **Mục đích:** Đẩy dữ liệu ảnh (ảnh chụp hoặc frame trích xuất từ video) lên server để xếp hàng suy luận AI.
- **Xác thực:** Công khai (**Không cần đăng nhập**).
- **Content-Type:** `multipart/form-data`
  - `file`: binary mảng byte ảnh (`MultipartFile.fromBytes`).
  - `filename`: tên file (`upload_<timestamp>.jpg`).
- **Response 200/201:**
  ```json
  { "job_id": "job_12345", "status": "queued" }
  ```

## `GET /api/jobs/{job_id}`
- **Mục đích:** Thăm dò định kỳ (polling mỗi 2 giây) trạng thái của job hoặc truy vấn kết quả.
- **Xác thực:** Công khai (**Không cần đăng nhập**).
- **Response 200 OK:**
  ```json
  {
    "job_id": "job_12345",
    "status": "completed",
    "result": {
      "prediction": "Amanita muscaria",
      "mushroom_name": "Nấm tán bay (Fly agaric)",
      "raw_prediction": "Amanita muscaria",
      "accepted_prediction": true,
      "confidence": 0.9452,
      "confidence_threshold": 0.70,
      "is_poisonous": true,
      "decision_reason": "Confidence above threshold",
      "image_type": "jpeg",
      "size_bytes": 142580,
      "sha256": "e3b0c442...",
      "inference_time_seconds": 0.384
    },
    "error": null
  }
  ```
- **Response 404:** Server không tìm thấy job (do khởi động lại máy chủ). App chuyển job thành `JobStatus.failed` với thông báo `"Job không tồn tại (404)"` và dừng polling job này.

## Giao thức WebSocket `/ws/queue`
- **Địa chỉ:** Chuyển đổi từ baseUrl: `http://host:port/ws/queue` -> `ws://host:port/ws/queue`.
- **Cơ chế Dual-Sync:**
  1. WebSocket lắng nghe các sự kiện: `queue.snapshot`, `queue.status`, `job.status`, `job.result`, `ws.connected`, `ws.closed`, `ws.error`.
  2. Fallback Polling: Timer 2 giây quét các job có trạng thái `queued` hoặc `processing` và gọi `GET /api/jobs/{job_id}` phòng trường hợp mất gói WebSocket.
- **Tự động phục hồi:** Tự động kết nối lại sau 2 giây nếu socket bị đóng ngoài ý muốn. Timeout 15 giây khi kiểm tra kết nối lần đầu.

