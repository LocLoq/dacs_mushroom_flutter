# 05 — Feature: Facility

## Files
- `lib/features/facility/data/facility_model.dart` — model (see `02-data-models.md`)
- `lib/features/facility/presentation/facility_list_screen.dart` — `FacilityListScreen` / `_FacilityListScreenState`

## State fields
```dart
final _api = ApiClient();
final _searchCtrl = TextEditingController();
List<FacilityModel> _all = [];   // full unfiltered list from API
FacilityStatus? _filter;         // null = show all statuses
bool _loading = true;
```

## Filtering — `_filtered` getter (recomputed on every build, not cached)
```dart
List<FacilityModel> get _filtered => _all.where((f) {
  final matchSearch = f.name.toLowerCase().contains(_searchCtrl.text.toLowerCase());
  final matchStatus = _filter == null || f.status == _filter;
  return matchSearch && matchStatus;
}).toList();
```
- Search is case-insensitive substring match on `name` only (not `address`).
- **All filtering is client-side** — see `03-api-contracts.md` note on `fetchFacilities`. If facility count grows large, move this logic server-side and pass `search`/`status` as query params instead.
- Search box `onChanged: (_) => setState(() {})` — empty-body `setState` exists only to force a rebuild so `_filtered` re-evaluates; it does not itself mutate state.

## Status → color/label mapping (`switch` expression, exhaustive)
```
FacilityStatus.active      → AppColors.success  / "Đang hoạt động"
FacilityStatus.paused      → AppColors.warning  / "Tạm dừng"
FacilityStatus.maintenance → AppColors.danger   / "Bảo trì"
```
If a new `FacilityStatus` enum value is ever added, the Dart compiler will error on these two `switch` expressions until both are updated (exhaustiveness is enforced) — this is intentional and should not be worked around with a `default:` case.

## "Switch active facility" dialog (`_openSelector`)
Tapping a facility card opens an `AlertDialog` ("Chuyển sang \"{name}\"?"). Confirm button currently only pops the dialog and shows a `SnackBar` — **it does not actually persist the selection anywhere** (no write to `LocalSession`/storage). This is the single biggest functional gap in this feature: the concept of "currently active facility" (referenced by `AppConstants.selectedFacilityKey`, unused) is not wired up at all. If asked to implement facility-switching, this is the entry point.

## UI structure
`Scaffold > RefreshIndicator(onRefresh: _load) > ListView`: search `TextField`, horizontal `ChoiceChip` row (built via `_filterChip` helper, one "Tất cả" + one per `FacilityStatus.values`), then `..._filtered.map((f) => Card(ListTile(...)))` with `StatusChip` trailing and `onTap: () => _openSelector(f)`.

## Known gaps / likely next tasks
- Selected facility is not persisted or used to scope data in other tabs (Strain/Account screens are not filtered by facility at all today, despite `AccountModel.assignedFacility` existing).
- No pagination — `fetchFacilities` returns everything; fine for mock data, will not scale.
- No create/delete facility UI exists yet (only Strain and Account have add/edit sheets). If asked to add "create facility", follow the `StrainFormSheet` pattern (`showModalBottomSheet` + `onSave` callback + `_load()` refresh).
