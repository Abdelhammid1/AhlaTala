# أحلى طلة — Backend

Flask 3 + SQLAlchemy 2 + PostgreSQL 16. Serves:
- **`/api/v1/*`** — public JSON API consumed by the Flutter customer app.
- **`/admin`** — session-authenticated Arabic RTL admin panel (Jinja + Bootstrap 5 RTL).

## First-time setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# copy env and fill DATABASE_URL with your local Postgres DSN
copy .env.example .env
# example DSN: postgresql+psycopg://ahla_tolla:changeme@127.0.0.1:5432/ahla_tolla

# create the database as superuser (once)
#   psql -U postgres -c "CREATE USER ahla_tolla WITH PASSWORD 'changeme';"
#   psql -U postgres -c "CREATE DATABASE ahla_tolla OWNER ahla_tolla;"

flask db init          # first time only, creates migrations/
flask db migrate -m "initial schema"
flask db upgrade
flask seed             # creates admin + 3 categories + sample items
flask run              # http://127.0.0.1:5000
```

Login to `/admin/login` with `admin@ahlatolla.local` / `admin`.

## API — Public v1

| Verb | Path | Purpose |
|---|---|---|
| GET | `/api/v1/categories` | Active categories with items count |
| GET | `/api/v1/categories/<id>/items` | Active items in a category (with `display_price_from` when variable) |
| GET | `/api/v1/items/<id>` | Full item + option groups + options |

Image URLs are absolute (built from `request.host_url + /static/...`), so the mobile app can load them without extra config.
