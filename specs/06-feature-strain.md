# 06 — Feature: Mushroom Strain

## Files

- `lib/features/mushroom_strain/data/strain_model.dart` — model (see `02-data-models.md`)
- `lib/features/mushroom_strain/presentation/strain_list_screen.dart` — `StrainListScreen`
- `lib/features/mushroom_strain/presentation/strain_form_sheet.dart` — `StrainFormSheet` (shared add/edit form)

## StrainListScreen state fields

```dart
final _api = ApiClient();
List<StrainModel> _strains = [];
bool _loading = true;
```

Standard load-on-`initState` pattern (see `01-architecture.md`). No search/filter on this screen (unlike Facility) — all strains always shown.

## `_openForm({StrainModel? existing})`

Single function handles both create and edit via an optional named param:

- `existing == null` → "Thêm giống nấm" (create)
- `existing != null` → "Chỉnh sửa giống nấm" (edit), form pre-filled from `existing`

Opens `StrainFormSheet` with `isScrollControlled: true` (needed because the form has 7 text fields and the keyboard would otherwise cover most of it). The `onSave` callback: `await _api.saveStrain(strain); Navigator.pop(context); _load();` — this is the canonical "props down, callback up" pattern used identically in `account_edit_sheet.dart`.

## StrainFormSheet internals

- 7 `TextEditingController`s, each `late final`, pre-seeded via `widget.existing?.field.toString() ?? ''`.
- **Temporary client-side ID generation for new strains:** `id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString()`. **This must be removed once the backend assigns real IDs** — flag any real backend integration PR that doesn't address this.
- Numeric fields parsed via `double.tryParse(ctrl.text) ?? 0` — silently defaults to `0` on invalid input rather than blocking submit. **No min<max validation exists** (e.g. nothing stops `tempMin: 40, tempMax: 10`) — the code has a TODO comment acknowledging this gap explicitly.
- `_saving` bool gates the submit button's loading state; no per-field error messages exist on this form (contrast with `AccountEditSheet._passwordError`, which does have one).

## UI structure (list)

`Scaffold` with `FloatingActionButton` (opens create form) + `ListView.builder` of `Card`s, each showing name, edit `IconButton`, and 3 `_paramTag` chips for temp/humidity/CO2 ranges (formatted `min–max unit`, e.g. `🌡 25–30°C`).

## Known gaps / likely next tasks

1. **Add min<max validation** in `StrainFormSheet._submit` before calling `onSave` (mirror the pattern in `AccountEditSheet._submitPassword`: check condition → `setState` error → `return;`).
2. **Remove temporary ID generation** once `ApiClient.saveStrain` returns a real server-assigned `StrainModel`.
3. **No delete function exists** for strains (or for any entity in this codebase) — if asked to add delete, there is no existing pattern to copy; design it fresh (likely: swipe-to-dismiss or a delete `IconButton` next to edit, calling a new `ApiClient.deleteStrain(id)` method).
4. No numeric-field range/unit validation beyond `tryParse` fallback to `0`.

## Điều hướng từ HomeScreen

`StrainListScreen` được mở từ mục thứ 4 trong sidebar của `HomeScreen`.

Màn hình yêu cầu người dùng đăng nhập trước khi truy cập.
Việc kiểm tra quyền quản lý giống nấm phải được thực hiện thêm ở backend.
