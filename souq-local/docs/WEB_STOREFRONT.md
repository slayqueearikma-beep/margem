# Dribex public web storefront

Production-ready Next.js App Router frontend for `https://dribex.ma`. It consumes the existing Dribex REST API and does not duplicate backend business logic.

## Local development

```bash
cd souq-local
docker compose up -d postgres api
docker compose exec api sh -c "cd /app && PYTHONPATH=. python scripts/seed_marketplace_demo.py"

cd web
cp .env.example .env.local
# Browser calls API at localhost:8000
npm install
npm run dev
```

Open `http://localhost:3000`.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_SITE_URL` | Canonical public site URL (`https://dribex.ma`) |
| `NEXT_PUBLIC_API_BASE_URL` | Browser-facing API base for media URLs and client fetches |
| `API_BASE_URL` | Server-side API base (use `http://api:8000` in Docker) |
| `NEXT_PUBLIC_LAUNCH_CITIES` | Comma-separated launch cities for city discovery fallback |

## Docker

```bash
cd souq-local
docker compose up -d
```

Services:

- `web` → `http://localhost:3000`
- `api` → `http://localhost:8000`

## Production routing

Terminate TLS at nginx and route:

- `dribex.ma` → `web:3000`
- `api.dribex.ma` → `api:8000`

Set `CORS_ORIGINS` to include `https://dribex.ma` and `https://www.dribex.ma`.

## Public pages

- `/` home/discovery
- `/search` search
- `/categories`, `/categories/[slug]`
- `/products`, `/products/[id]`
- `/services`, `/services/[id]`
- `/sellers`, `/sellers/[id]`
- `/cities`, `/cities/[slug]`
- `/marketplaces/[slug]` when marketplace APIs are enabled

Authentication-required actions remain in the mobile app.
