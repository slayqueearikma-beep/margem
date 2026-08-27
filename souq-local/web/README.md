# Dribex public web storefront

Next.js App Router frontend for `https://dribex.ma`.

## Prerequisites

- Node.js 20+
- Running Dribex API (default `http://localhost:8000`)

## Local development

**You must install dependencies once** (`cp env.example` alone is not enough).

From the repo root:

```bash
cd souq-local
docker compose up -d postgres api
./scripts/dev-web.sh
```

Or from `souq-local/web`:

```bash
npm run setup    # installs deps + creates .env.local
npm run dev
```

Manual steps:

```bash
cd souq-local/web
cp env.example .env.local
npm install      # required — do not skip; do not use sudo
npm run dev
```

Open http://localhost:3000

Do **not** use `sudo npm install` — that skips `node_modules/.bin/next` on your user PATH and causes `next: not found`.

## Docker (production-like)

```bash
cd souq-local
docker compose up -d --build
```

Storefront: http://localhost:3000

See `../docs/WEB_STOREFRONT.md` for deployment details.
