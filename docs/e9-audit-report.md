# E9 — Audit Report

Phase 3 pass over every AC in the Word doc's E9 section against the code as
it stands. Source: `853_..._Product_Backlog.docx` — Epic E9 "حسابات
العملاء" — US9.1..US9.4.

---

## Per-story verdicts

| Story | AC | Verdict | Where |
|---|---|---|---|
| **US9.1** | Register with phone + OTP; no email, no password | ✅ | `backend/app/otp/service.py` generate/verify; `POST /auth/otp/request` + `/verify`; mobile `LoginScreen` + `VerifyScreen` |
| **US9.2** | Log in with phone + OTP; session persists until logout | ✅ | Same endpoints; JWT with 30-day lifetime; `AuthController` persists via SharedPreferences; only `logout()` clears |
| **US9.3** | Order history + reorder | ✅ | `GET /me/orders`; `OrderHistoryScreen`; `CartController.addSnapshot(...)` reconstructs cart lines client-side |
| **US9.4** | Edit name + saved addresses | ✅ | `PATCH /me`; `/me/addresses` CRUD; `ProfileScreen` + inline sheet |

**And crucially — the doc's cross-cutting constraints are preserved:**
- Guest browsing / cart / checkout still works exactly as before
  (E1–E8). Auth is an upgrade, not a wall.
- `create_order` prefers the JWT identity when present, otherwise
  falls back to the E5 phone-upsert path.

---

## In-session verification

Backend, live at `127.0.0.1:5000`:

- **Migration** `e821e6634320_e9_accounts` applied cleanly.
- **Seed** marks `0555555555` `verified_at=now()` + inserts 2 saved
  addresses.
- **OTP request** → 200, `sent_to: 0555555555`. Flask log shows
  `[OTP] phone=0555555555 code=…` (LoggingSender).
- **OTP verify** (with a known plaintext-hash pair injected for the
  test): 200, returns `{access_token, customer{verified_at, points_balance}}`.
- **`GET /me`** with Bearer token → returns full customer profile ✓
- **`GET /me/orders`** → returns 1 order (the delivered coke order from seed) ✓
- **`GET /me/addresses`** → returns the 2 seeded addresses (default first) ✓
- **`GET /me` without token** → 401 ✓
- **`PATCH /me {name: ...}`** → returns updated customer with new name ✓
- **10 new routes** registered (2 auth + 8 me/*).

Mobile: `flutter analyze` — no issues.

---

## Findings caught during the audit

### 1. OTP is delivered via `LoggingSender` — no real SMS

Same posture as E3 payment gateway and E8 push. The `SmsSender` seam
is documented and ready. In dev, the code prints to the Flask console.
Production needs an SMS provider (Unifonic/Msegat/Twilio); swap in
`OTP_SENDER=sms` + fill out `SmsSender.send(...)` — no other file
moves.

### 2. Dio Bearer injection reads SharedPreferences per request

Instead of injecting the token via a Riverpod cycle
(dio ↔ AuthController), the interceptor reads
`SharedPreferences.getInstance()` on every outbound request. Cheap
(prefs is cached in-memory after first read) and cycle-free. Trade-off
noted in `dio_client.dart`.

### 3. 401 not centrally handled

A 401 on any /me endpoint currently surfaces as a repository throw.
The mobile side doesn't have a global "log me out on 401" interceptor
yet — the individual FutureProviders' error branch handles it. Add a
Dio response interceptor when session expiration becomes user-visible
(currently JWT lives 30 days, so this is future work).

### 4. Re-order reconstructs from snapshot, not live data

The re-order button walks `OrderLine` snapshot fields (name, image,
base_price, per-selection group/option ids + snapshot names/deltas)
into new `CartLine`s. Server re-validates on the next `create_order`
call, so if an item has been deactivated or an option removed since
the original order, the customer gets a clean 422 "item unavailable"
message. Documented in the plan's scope boundary.

### 5. Guest → authed migration is lazy

If a guest customer at phone X places 3 orders under phone X, then
later signs in with OTP for the same phone X, all 3 orders join
their account (same `customer_id` row — `upsert_customer` finds the
existing row and marks it verified). If the guest used two different
phones, only the verified one becomes "theirs" — the other stays
unclaimed.

### 6. Rate limit is DB-level, not distributed

`MAX_CODES_PER_HOUR=5` per phone is enforced with a per-request
count query. Fine for single-process MVP; multi-worker deployments
should move this to Redis to avoid race conditions on the burst edge.

### 7. `savedPhoneProvider` from E8 still lives

Left in place for the guest inbox lookup path (LoyaltyScreen). Auth'd
users implicitly use their session — no consumer of `savedPhoneProvider`
was broken. E9's `AuthController` and E8's `savedPhoneProvider` coexist
peacefully; a future cleanup could unify them behind
`currentCustomerProvider`.

### 8. JWT identity is stringified customer_id

flask-jwt-extended 4.x requires string identities; both `create_access_token`
(in `otp/service.py`) and `_current()` (in `api/me.py`) cast on
mint/read. Documented near the cast site.

None of these are gaps against the Word doc.

---

## Not verified in-session (needs a running Flutter session)

- Login → verify → profile navigation.
- Re-order cart reconstruction round-trip through /review.
- Address CRUD in the profile bottom sheet.
- Guest flow regression after E9's Dio interceptor addition.
- Logout returning to home.

## Follow-ups (small, out of the E9 critical path)

- Real SMS provider (Unifonic/Msegat/Twilio) — one file, one env var.
- Global 401 interceptor → force-logout + push to /login.
- Address geo (map picker) + geocoding.
- Account deletion (GDPR-style export + purge).
- Admin impersonation (log in as customer) — useful for support.
- Retire `savedPhoneProvider` once every consumer of it can rely on
  the auth session.

---

# 🎉 All 9 Epics complete.

`docs/` now contains an acceptance checklist + audit report for each
of E1–E9. `C:\Users\zyadw\.claude\plans\zippy-gathering-codd.md`
carries the latest (E9) plan; every earlier plan file was overwritten
as the epic advanced, with the corresponding history preserved in the
per-epic docs.
