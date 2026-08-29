# أحلى طلة — AhlaTala

A full-stack ordering platform for the أحلى طلة restaurant: Flutter customer app + Flask/PostgreSQL backend + custom Jinja admin panel. Arabic RTL throughout.

Built end-to-end against the printed product backlog (`853_20260828235037_Ahla_Tolla_Product_Backlog.docx`) — all **9 Epics** shipped, with an acceptance checklist and audit report per Epic under `docs/`.

---

## Stack

| Layer | Tech |
|---|---|
| Mobile | Flutter 3.41 · Riverpod 2 · Dio · go_router · cached_network_image · shared_preferences · flutter_local_notifications |
| Backend | Flask 3 · SQLAlchemy 2 · PostgreSQL 16 · Flask-Migrate · Flask-JWT-Extended · Flask-Login · Flask-CORS · marshmallow |
| Admin | Jinja2 · Bootstrap 5 RTL · Bootstrap Icons · Cairo font |

## Repository Layout

```
.
├── backend/                Flask app (API + Jinja admin)
│   ├── app/                  application factory + models + api + admin + business logic
│   │   ├── api/              /api/v1/* — public JSON endpoints (Flutter)
│   │   ├── admin/            /admin/* — Jinja panel (staff)
│   │   ├── models/           SQLAlchemy models
│   │   ├── templates/admin/  Jinja templates
│   │   ├── static/           uploads/ + brand/
│   │   ├── loyalty.py        E5 engine
│   │   ├── discounts.py      E6 engine
│   │   ├── observers.py      SQLAlchemy events (order_number, price recompute, loyalty award)
│   │   ├── payments/         E3 sender seam (cash + stub gateway)
│   │   ├── notifications/    E8 sender seam
│   │   └── otp/              E9 OTP sender + verifier
│   ├── migrations/           Alembic (Flask-Migrate) — one revision per Epic
│   ├── seed.py               `flask seed` — sample menu + one customer
│   ├── import_menu.py        `flask import-menu` — imports the printed menu
│   ├── mock_images.py        `flask mock-images` — assigns placeholder food photos
│   └── run.py                dev entrypoint
├── mobile/                 Flutter app
│   └── lib/
│       ├── core/             theme, dio client, prefs, env, brand logo
│       ├── data/             models, repositories
│       └── features/         menu, item_details, cart, checkout, loyalty, discounts, home, notifications, auth, profile
├── docs/                   acceptance checklists + audit reports (2 files per Epic)
├── 853_..._Product_Backlog.docx    source of truth (Word doc)
└── احلى طلة  جاهز.pdf             restaurant logo (PDF)
```

## The 9 Epics

Each Epic ships with a **plan → implement → audit** cycle. Every doc file is under `docs/`.

| # | Epic (Arabic) | English | Docs |
|---|---|---|---|
| E1 | إعداد المنيو والتصفح | Menu setup & browsing (generic option-groups engine: variant · size · add · remove) | `e1-*.md` |
| E2 | السلة وإتمام الطلب | Cart, delivery/pickup, cross-sell recommendations, review | `e2-*.md` |
| E3 | الدفع | Payment — cash + stubbed Saudi gateway via a `PaymentProvider` seam | `e3-*.md` |
| E4 | إدارة الطلبات (Admin) | Admin order management — status workflow with logical transitions, live-ish mobile timeline | `e4-*.md` |
| E5 | نظام نقاط الولاء | Loyalty — auto-accrual on delivered, checkout redemption | `e5-*.md` |
| E6 | أكواد الخصم | Discount codes — percent/fixed, min basket, expiry, usage cap; stacks with points | `e6-*.md` |
| E7 | العروض والأكثر طلبًا | Time-boxed offers + SQL-aggregated most-ordered | `e7-*.md` |
| E8 | الإشعارات | Admin broadcasts + local push (FCM seam ready) | `e8-*.md` |
| E9 | حسابات العملاء | Phone + OTP auth, profile, saved addresses, order history + reorder | `e9-*.md` |

## Deferred integrations (stubbed with clean seams)

Three third-party services need an account/credentials to go live; the code seams for each are done. Swap in one file per service:

| Service | Seam | To activate |
|---|---|---|
| Saudi payment gateway (Moyasar / HyperPay / Tap) | `backend/app/payments/stub_gateway.py` | Replace with SDK call in the same class |
| Firebase Cloud Messaging | `backend/app/notifications/sender.py` `FcmSender` | Set `SENDER=fcm`, fill in `.send()` |
| SMS provider (Unifonic / Msegat / Twilio) | `backend/app/otp/sender.py` `SmsSender` | Set `OTP_SENDER=sms`, fill in `.send()` |

---

## Quick start (dev)

### Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Copy .env template and fill your Postgres DSN
copy .env.example .env

# Create the DB (once, as postgres superuser):
#   psql -U postgres -c "CREATE USER ahla_tolla WITH PASSWORD 'changeme';"
#   psql -U postgres -c "CREATE DATABASE ahla_tolla OWNER ahla_tolla;"

flask db upgrade          # apply all migrations
flask seed --wipe         # + one demo customer + a welcome notification
flask import-menu --wipe  # import the printed menu (119 items)
flask mock-images         # placeholder photos until real ones are uploaded

flask run --host 127.0.0.1 --port 5000
```

Admin panel: <http://127.0.0.1:5000/admin/login>
Default credentials: `admin@ahlatolla.local` / `admin` (change before going live).

### Mobile

```powershell
cd mobile
flutter pub get

# Emulator (Android):
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Physical phone over USB (use `adb reverse tcp:5000 tcp:5000` first):
flutter run -d <device-id> --dart-define=API_BASE_URL=http://127.0.0.1:5000

# iOS simulator / desktop / web:
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

### CORS

`Flask-CORS` allows any origin to hit `/api/v1/*`, so Flutter Web and any host work out of the box in dev.

---

## Testing & audit

Every Epic has:
- **`docs/eN-acceptance-checklist.md`** — every AC from the Word doc as a manual test step
- **`docs/eN-audit-report.md`** — where the AC is satisfied in code, plus trade-offs and follow-ups caught during the audit

No AC gaps are open across E1–E9.

---

## License / attribution

Restaurant branding (logo, name, menu content) © أحلى طلة.
