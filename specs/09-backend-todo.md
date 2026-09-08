# 09 — Backend TODO (consolidated)

Every item below corresponds to a `// TODO(BACKEND)` comment already present in the code (locations given), plus gaps discovered during spec review that have no comment yet. Grep to re-verify: `grep -rn "TODO(BACKEND)" lib/`.

## Endpoints to implement (Django REST Framework assumed, per existing comments)

| # | Endpoint | Method | Caller in code | Auth |
|---|---|---|---|---|
| 1 | `/auth/login/` | POST | `ApiClient.login` | public |
| 2 | `/facilities/` | GET | `ApiClient.fetchFacilities` | logged in |
| 3 | `/strains/` | GET | `ApiClient.fetchStrains` | logged in |
| 4 | `/strains/` or `/strains/{id}/` | POST / PUT | `ApiClient.saveStrain` | logged in |
| 5 | `/accounts/` | GET | `ApiClient.fetchAccounts` | **admin/manager only** |
| 6 | `/accounts/{id}/` | PATCH (`is_active`) | `ApiClient.toggleAccountLock` | admin/manager only |
| 7 | `/accounts/{id}/` | PATCH (`role`, `assigned_facility`) | `ApiClient.updateAccountRole` | **admin only** |
| 8 | `/accounts/{id}/set-password/` | POST | `ApiClient.setAccountPassword` | admin/manager only |

## Endpoints FastAPI (AI Recognition & Catalog — Không cần đăng nhập)

| # | Endpoint | Method | Caller in code | Auth |
|---|---|---|---|---|
| 9 | `/api/mushrooms/catalog` | GET | `ApiClient.fetchMushroomCatalog` | **public (không cần login)** |
| 10 | `/api/images/upload` | POST (Multipart) | `BackendQueueService.enqueue` | **public (không cần login)** |
| 11 | `/api/jobs/{job_id}` | GET (Polling) | `BackendQueueService.fetchJob` | **public (không cần login)** |
| 12 | `/ws/queue` | WebSocket | `BackendQueueService.connect` | **public (không cần login)** |

Full request/response shapes for each: see `03-api-contracts.md`.

## Client-side infrastructure not yet added (packages)
- [ ] `dio` — replace `ApiClient`'s mock bodies with real HTTP calls. Template for the `Dio` instance + JWT interceptor + 401-handling already exists as a comment at the top of `api_client.dart` — implement it as written there.
- [ ] `flutter_secure_storage` — persist JWT token across app restarts (`LocalSession` is currently RAM-only; see `08-shared-core.md`).
- [ ] `hive` — offline cache for facility/strain lists (mentioned in original architecture doc, not yet started).
- [ ] Consider `go_router` if route guarding (e.g. redirect-to-login, admin-only routes) becomes necessary — not required for current scope.

## Security requirements to enforce server-side (client cannot be trusted to enforce these)
1. **Password strength validation** — client checks length ≥ 6 and match-confirmation only, for UX. Server must independently validate (comment in `account_edit_sheet.dart` / `api_client.dart`).
2. **No password-read endpoint** — by design, do not add a GET that returns any password, hashed or not, to the client.
3. **Role-change authorization** — only Admin should be able to call endpoint #7. Enforce via `permission_classes`, not client UI hiding.
4. **Account-list authorization** — only Admin/Manager should be able to call endpoint #5.
5. **`must_change_password` enforcement** — when true, auth middleware should block all API calls for that user except a dedicated "change my own password" endpoint (not endpoint #8, which is for an admin resetting someone else's password — the two flows must stay separate: self-service change requires the old password, admin-reset does not).

## Data-model reconciliation needed before/during backend work
1. `AccountModel.assignedFacility` is currently a free-text facility **name** on the client; backend contract in `03-api-contracts.md` assumes a facility **id**. Pick one and update both sides consistently (recommend id, with client resolving display name from the already-fetched facility list).
2. `StrainModel` has no server ID scheme yet — client currently fabricates a temporary id (`DateTime.now().millisecondsSinceEpoch`) for new strains. Once `saveStrain` returns a real created/updated object with a server id, remove the client-side id fabrication (`strain_form_sheet.dart`).
3. `LocalSession.role` (raw string like `"Manager"`) and `AccountRole` enum (lowercase `manager`) are two different representations of the same concept and are not currently reconciled anywhere. Needed before implementing any role-based UI gating.
4. Confirm whether `mustChangePassword` should survive a role/facility edit — currently it is silently reset to `false` whenever `AccountListScreen`'s `onSaveRole` reconstructs the `AccountModel` (see `07-feature-account.md`). Decide intended behavior and fix client if wrong.

## Explicitly out of scope / not started at all (no code exists yet)
- Facility create/edit/delete UI and endpoints.
- Strain delete UI and endpoint.
- Account create/delete UI and endpoint.
- "Currently selected facility" persistence and any data-scoping by facility (Strain/Account lists are not filtered by facility today).
- Forgot-password / refresh-token flow.
- Any automated tests (`test/` folder exists from the Flutter template but has not been customized for this app's screens/models).
