# 01 — Architecture

## Layer rule (strict, never violate)

```
features/*/presentation/  →  features/*/data/  +  core/*  +  app/theme/
features/*/data/          →  (nothing — leaf nodes, pure Dart, no imports of app/core/features)
core/network/api_client.dart → features/*/data/  (only exception: needs return types)
core/services/*           →  core/*, features/*/data/
core/widgets/*             →  app/theme/app_colors.dart  only (never features/*)
core/storage/*             →  (nothing)
app/*                      →  features/*/presentation/, core/*, app/theme/, app/config/
```

**Never** import a `presentation/` file from a `data/` file, and never import a `features/X` file from `core/widgets/`. If you need a widget to know about a feature's model, pass it as a constructor parameter instead — do not add the import.

All imports in this codebase are **relative** (`../../core/...`), not `package:thu/...`. Keep new files consistent with this — do not introduce package-style imports.

## HomeScreen

File: `lib/app/home_screen.dart`

- `HomeScreen` là shell điều hướng chính của ứng dụng.
- Điều hướng sử dụng sidebar.
- Sidebar chứa 6 module:
  - `MushroomRecognitionScreen`
  - `MushroomCatalogScreen`
  - `FacilityListScreen`
  - `StrainListScreen`
  - `BatchListScreen`
  - `AccountListScreen`
- `initialIndex` xác định module được mở ban đầu.
- `_index` xác định nội dung đang hiển thị.
- `_isSidebarVisible` điều khiển trạng thái hiển thị sidebar.
- `FirstRunBackendDialog.checkAndShow(context)` được gọi sau frame đầu tiên.

## Full file tree (lib/)

```
lib/
├── main.dart                                          # entry point, calls runApp(MushroomApp())
├── app/
│   ├── app.dart                                        # MushroomApp: MaterialApp root, đa ngôn ngữ, theme mode
│   ├── home_screen.dart                                # HomeScreen: bottom-nav shell, 5 tabs
│   ├── theme/
│   │   ├── app_colors.dart                             # AppColors: static Color constants
│   │   └── app_theme.dart                              # AppTheme.light() & AppTheme.dark()
│   └── config/
│       ├── env_config.dart                             # EnvConfig: baseUrl, timeouts
│       └── app_constants.dart                          # AppConstants: storage key names, default backend URL
├── core/
│   ├── localization/
│   │   ├── app_language.dart                           # AppLanguage enum (vi, en)
│   │   └── app_text_scope.dart                         # AppTextScope (InheritedWidget) + tr() helper
│   ├── models/
│   │   └── app_config.dart                             # AppConfig model
│   ├── network/
│   │   └── api_client.dart                             # ApiClient: REST API & mock endpoints
│   ├── services/
│   │   ├── app_preferences_service.dart                # Quản lý SharedPreferences (URL, theme, lang)
│   │   ├── backend_queue_service.dart                  # Quản lý WS /ws/queue + Dual-Sync polling + Upload
│   │   ├── frame_selector_service.dart                 # Thuật toán chọn frame video & chấm điểm chất lượng
│   │   └── recognition_history_service.dart            # Lưu trữ lịch sử 200 items + quản lý file media
│   ├── storage/
│   │   └── local_session.dart                          # LocalSession: in-RAM auth state
│   └── widgets/
│       ├── custom_button.dart                          # CustomButton
│       ├── custom_textfield.dart                       # CustomTextField
│       └── status_chip.dart                            # StatusChip
└── features/
    ├── auth/
    │   └── presentation/
    │       └── login_screen.dart                       # LoginScreen (hỗ trợ vào trực tiếp tính năng công khai)
    ├── facility/
    │   ├── data/
    │   │   └── facility_model.dart                     # FacilityModel, FacilityStatus enum, mockFacilities
    │   └── presentation/
    │       └── facility_list_screen.dart                # FacilityListScreen (cần đăng nhập)
    ├── mushroom_strain/
    │   ├── data/
    │   │   └── strain_model.dart                        # StrainModel, mockStrains
    │   └── presentation/
    │       ├── strain_list_screen.dart                  # StrainListScreen (cần đăng nhập)
    │       └── strain_form_sheet.dart                   # StrainFormSheet (add/edit BottomSheet)
    ├── account/
    │   ├── data/
    │   │   └── account_model.dart                       # AccountModel, AccountRole enum, mockAccounts
    │   └── presentation/
    │       ├── account_list_screen.dart                 # AccountListScreen (cần đăng nhập)
    │       └── account_edit_sheet.dart                  # AccountEditSheet (role + password BottomSheet)
    ├── recognition/
    │   ├── data/
    │   │   ├── job_status.dart                         # JobStatus enum + color/label/icon helpers
    │   │   ├── prepared_frame.dart                     # PreparedFrame model
    │   │   ├── queue_job.dart                          # QueueJob model
    │   │   └── queue_event.dart                        # QueueEvent model
    │   └── presentation/
    │       ├── mushroom_recognition_screen.dart         # MushroomRecognitionScreen (công khai, không cần login)
    │       └── widgets/
    │           ├── job_result_card.dart                # Thẻ hiển thị job trong queue
    │           ├── result_payload_view.dart            # Khung hiển thị chi tiết kết quả dự đoán AI
    │           ├── result_row.dart                     # Dòng thông số kỹ thuật
    │           └── result_popup_dialog.dart            # Hộp thoại tự động hiển thị kết quả
    ├── recognition_history/
    │   ├── data/
    │   │   └── history_item.dart                       # RecognitionHistoryItem model
    │   └── presentation/
    │       ├── recognition_history_screen.dart         # RecognitionHistoryScreen (danh sách lịch sử)
    │       └── widgets/
    │           └── history_detail_dialog.dart          # Dialog xem chi tiết một bản ghi lịch sử
    ├── mushroom_catalog/
    │   ├── data/
    │   │   └── catalog_model.dart                      # MushroomCatalogResponse & Item model, mockCatalog
    │   └── presentation/
    │       └── mushroom_catalog_screen.dart            # MushroomCatalogScreen (công khai, không cần login)
    └── settings/
        └── presentation/
            ├── settings_screen.dart                    # SettingsScreen (cấu hình IP, WS, dark mode, ngôn ngữ)
            └── first_run_backend_dialog.dart           # Dialog hướng dẫn thiết lập backend lần đầu
```

## Naming conventions in use

- File names: `snake_case.dart`. Class names: `PascalCase`.
- Screen widgets end in `Screen` (e.g. `FacilityListScreen`). Bottom-sheet/dialog form widgets end in `Sheet` (e.g. `StrainFormSheet`, `AccountEditSheet`).
- Private State classes: `_XxxState` for `class Xxx extends StatefulWidget`.
- Mock data constants: `mockXxx` (lowerCamel, plural), colocated in the same file as the model they instantiate.
- Every unimplemented backend integration point is marked `// TODO(BACKEND): ...` — grep for this tag to find all integration points (`grep -rn "TODO(BACKEND)" lib/`).

## Widget composition pattern used throughout (for any new feature)

Every list screen (`FacilityListScreen`, `StrainListScreen`, `AccountListScreen`) follows the same lifecycle:

1. `State` holds `ApiClient _api`, a `List<XModel> _items = []`, `bool _loading = true`.
2. `initState()` calls `super.initState()` then a private `_load()`.
3. `_load()` is `async`, calls `_api.fetchX()`, then `setState(() { _items = data; _loading = false; })`.
4. Any create/edit flow opens a `showModalBottomSheet` with a form widget that takes an `onSave` callback (`Future<void> Function(XModel)`); the callback calls the API then `Navigator.pop(context)` then re-`_load()`.

When adding a new feature, replicate this pattern exactly rather than inventing a new one.
