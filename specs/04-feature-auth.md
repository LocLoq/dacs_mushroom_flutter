# 04 — Feature: Auth

## File

`lib/features/auth/presentation/login_screen.dart` — `LoginScreen` (StatefulWidget), `_LoginScreenState`.

## Gap vs. architecture convention

No `lib/features/auth/data/` folder exists (unlike facility/strain/account, which each have one). Auth currently has no dedicated model — see `02-data-models.md` "Auth model — no dedicated file". If a task requires typed auth data, create `auth_model.dart` there rather than putting a model class inline in the screen file.

## State fields

```dart
final _api = ApiClient();
final _userCtrl = TextEditingController();
final _passCtrl = TextEditingController();
bool _obscure = true;   // password visibility toggle
bool _loading = false;  // gates button + shows spinner
String? _error;         // null = no error shown

## Auth gate trong HomeScreen

`HomeScreen` kiểm tra `LocalSession.isLoggedIn` trước khi hiển thị:

- `FacilityListScreen`
- `StrainListScreen`
- `BatchListScreen`
- `AccountListScreen`

Nếu người dùng chưa đăng nhập, Home hiển thị `_AuthRequiredPlaceholder` thay vì màn hình chức năng.

Nhận diện AI và Từ điển không yêu cầu đăng nhập.

Sau khi đăng nhập thành công, Home gọi `setState` để dựng lại nội dung hiện tại.
```

## Flow (`_handleLogin`)

1. `setState` → `_loading = true`, `_error = null`.
2. `await _api.login(_userCtrl.text.trim(), _passCtrl.text)`.
3. On success: `LocalSession.save(result['access'], result['user'])`, guard with `if (!mounted) return;`, then `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()))`.
4. On thrown `Exception`: caught, message stripped of the `"Exception: "` prefix, stored in `_error`, rendered below the password field.
5. `finally`: `_loading = false` (guarded by `mounted`).

## Navigation semantics

Uses `pushReplacement`, not `push` — deliberate, so the back button cannot return to the login screen after a successful login. Any future "logout" flow should mirror this (`pushReplacement` back to `LoginScreen`, and should call `LocalSession.clear()` first).

## Phân quyền & Tính năng công khai (KHÔNG CẦN ĐĂNG NHẬP)

- **Quy tắc quan trọng:** Người dùng **hoàn toàn không cần đăng nhập** để sử dụng tính năng **Nhận diện AI** (`MushroomRecognitionScreen`) và **Từ điển nấm** (`MushroomCatalogScreen`).
- Tại màn hình đăng nhập `LoginScreen`: Có thêm nút liên kết _"Khám phá ngay (Không cần đăng nhập)"_ hoặc _"Sử dụng nhận diện nấm"_ dẫn thẳng đến `HomeScreen` với tab Nhận diện / Từ điển.
- Tại `HomeScreen`: Người dùng chưa đăng nhập có thể dùng tự do tab Nhận diện và Từ điển. Khi nhấn vào các tab quản lý nội bộ (`Cơ sở`, `Giống nấm`, `Tài khoản`), app hiển thị thông báo yêu cầu đăng nhập hoặc mở modal `LoginScreen`.

## UI composition

`Scaffold > SafeArea > Center > SingleChildScrollView > Column(stretch)`: icon, title text, `CustomTextField` (username), `CustomTextField` (password, `obscure: _obscure`, eye-icon `suffixIcon` toggles it), conditional error `Text`, `CustomButton` (`loading: _loading`), và nút TextButton _"Sử dụng tính năng Nhận diện Nấm không cần đăng nhập"_.

## Known gaps / likely next tasks here

- No "remember me" / persistent session — every app restart requires re-login (see `LocalSession` in `08-shared-core.md`).
- No forgot-password flow.
- No input validation before calling `login` beyond empty-check inside the mock itself — if adding client-side validation, follow the pattern in `AccountEditSheet._submitPassword` (validate → `setState` error string → `return;` early).
- No `refresh` token handling — `login`'s mock response has no `refresh` field even though the intended contract in `03-api-contracts.md` mentions one from the Dio template comment. Reconcile before real implementation.
