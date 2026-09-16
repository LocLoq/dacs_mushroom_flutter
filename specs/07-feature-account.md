# 07 — Feature: Account

## Files

- `lib/features/account/data/account_model.dart` — model (see `02-data-models.md`)
- `lib/features/account/presentation/account_list_screen.dart` — `AccountListScreen`
- `lib/features/account/presentation/account_edit_sheet.dart` — `AccountEditSheet`

## Purpose

Admin/manager-only screen (per `03-api-contracts.md` permission notes — **not currently enforced client-side either**, i.e. any logged-in user can currently open this tab; enforcement is a TODO) for managing staff: view role/facility assignment, lock/unlock login access, change role, and reset password.

## AccountListScreen state fields

```dart
final _api = ApiClient();
List<AccountModel> _accounts = [];
bool _loading = true;
```

Standard load pattern. No search/filter (unlike Facility).

## Lock/unlock toggle (`_toggleLock`)

```dart
await _api.toggleAccountLock(a.id);
setState(() => a.isActive = !a.isActive);
```

Works because `a` is a direct reference into `_accounts` (not a copy) and `isActive` is mutable — no need to find-and-replace by index for this one field. Contrast with role/facility changes below.

## Role/facility edit (`_openEditSheet` → `onSaveRole`)

Because `role` and `assignedFacility` are `final` on `AccountModel` (immutable by design — see `02-data-models.md`), updating them requires replacing the whole object:

```dart
await _api.updateAccountRole(a.id, role, facility);
setState(() {
  _accounts[_accounts.indexOf(a)] = AccountModel(
    id: a.id, fullName: a.fullName, role: role,
    assignedFacility: facility, isActive: a.isActive,
  );
});
```

**Note:** this reconstruction does not carry over `mustChangePassword` — it implicitly resets to the model's default (`false`) unless explicitly passed. Verify this is intended before shipping; it is a likely latent bug if a user's `mustChangePassword: true` flag gets silently cleared just by editing their role.

## Password reset + forced-change flow (`onSavePassword`)

```dart
await _api.setAccountPassword(a.id, newPassword, mustChangePassword: mustChangePassword);
setState(() => a.mustChangePassword = mustChangePassword);
```

This one _is_ a direct mutation (mustChangePassword is mutable), unlike role/facility.

### `AccountEditSheet` internals

- Two independent sections in one `BottomSheet`, each with its own submit button and own loading/error state (`_savingRole`/`_savingPassword`, single shared `_passwordError`):
  1. **Role & facility**: `DropdownButtonFormField<AccountRole>` (built from `AccountRole.values`) + `CustomTextField` for facility (free text, not a picker — see model gap in `02-data-models.md`). Submits via `onSaveRole`.
  2. **Password reset**: two obscured `CustomTextField`s (new + confirm) with independent visibility toggles, client-side validation (`_submitPassword`): length ≥ 6, must match confirm — both explicit `TODO(BACKEND)`-flagged as UX-only, backend must re-validate. On success, both controllers are cleared (security hygiene — do not remove this).
  3. **"Buộc đổi mật khẩu lần đăng nhập tiếp theo" checkbox** (`_mustChangePassword`, a `CheckboxListTile`): intentionally placed as the **last** element in the sheet, below the "Cập nhật mật khẩu" button (moved there per explicit request — do not "fix" this back above the button without checking with whoever owns UX). It is still submitted together with `_submitPassword()`, not independently — there is no separate save action for it.

## Security invariants — do not violate these in future edits

1. There is no "view password" capability anywhere in this feature — only "set new password". Do not add one.
2. Client-side password validation is UX convenience only; real enforcement must happen server-side (explicit code comment/TODO).
3. Role changes must be server-side-restricted to Admin callers only (explicit code comment/TODO) — client currently does not even check the current user's own role before showing the edit button, so this is purely a backend responsibility today.

## UI list rendering

Each row: avatar (first letter of name, colored by role), name, `StatusChip` for role + plain text for facility + conditional `StatusChip("Chờ đổi mật khẩu", warning)` when `mustChangePassword == true`, trailing edit `IconButton` + `Switch` for lock/unlock.

## Known gaps / likely next tasks

- No account creation UI (only edit existing mock accounts).
- No delete-account UI.
- `assignedFacility` is free text, not linked to `FacilityListScreen`'s data — should likely become a dropdown sourced from `ApiClient.fetchFacilities()` once facility linking is implemented (mirrors the model gap in `02-data-models.md`).
- Role reconstruction dropping `mustChangePassword` (see above) — verify/fix.
- No admin-only route guard exists yet — every screen is reachable by any logged-in user regardless of `LocalSession.role`.

## Điều hướng từ HomeScreen

`AccountListScreen` được mở từ mục thứ 6 trong sidebar của `HomeScreen`.

Home chỉ kiểm tra trạng thái đăng nhập bằng `LocalSession.isLoggedIn`.
Quyền admin/manager vẫn phải được kiểm tra ở backend; đăng nhập thành công không đồng nghĩa với có quyền quản trị tài khoản.
