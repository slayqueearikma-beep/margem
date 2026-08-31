# Dribex On-Prem Production (Ubuntu)

Production Docker Compose stack for **public Internet** deployment.

## Architecture

```text
PUBLIC INTERNET
      |
      | HTTPS :443
      v
    NGINX  (only public entry point — ports 80/443)
      |
      +----> Web :3000
      |
      +----> API :8000
                 |
     PostgreSQL | Redis | MinIO | Vault (internal network only)
                 |
     Prometheus | Loki | Grafana (internal — SSH tunnel for admin)
```

Only **nginx** exposes host ports `80` and `443`. Postgres, Redis, MinIO, Vault, API, and Web are **not** published on the public interface.

**Tailscale** remains for SSH and private admin access only — not for end-user traffic.

## Quick start

```bash
cd infra/onprem
cp env.prod.example .env.prod
# Edit secrets — never commit .env.prod

./scripts/validate-production-env.sh .env.prod
./scripts/deploy.sh
```

## TLS (required for public mobile)

Replace bootstrap self-signed certs before public launch:

1. **Cloudflare Origin Certificate** (if using Cloudflare proxy) — see `docs/PUBLIC_TLS_SETUP.md`
2. **Let's Encrypt** — if the server is directly reachable on port 443

Install files as:

- `nginx/certs/fullchain.pem`
- `nginx/certs/privkey.pem`

Then: `docker compose -f docker-compose.prod.yml --env-file .env.prod restart nginx`

## Media / MinIO

Media is served **only through the API** at `/media/{bucket}/{key}` with authorization checks.

- Do **not** set `MINIO_PUBLIC_URL` in production.
- Nginx does **not** expose `/storage/` (direct MinIO proxy removed).

## Backups

```bash
./scripts/backup.sh
./scripts/restore.sh /var/backups/margem/postgres-YYYYMMDD-HHMMSS.sql.gz
```

Backs up PostgreSQL and **all** MinIO buckets via the `minio/mc` sidecar image.

Schedule via cron. Copy `/var/backups/margem` off-server.

## Public launch verification

```bash
./scripts/verify-public-api.sh
./scripts/production-gate-check.sh
```

From repo root (after deploy):

```bash
./scripts/production-deploy.sh
```

## Monitoring

Grafana is internal-only. Access via SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 user@your-server
docker compose -f docker-compose.prod.yml --env-file .env.prod port grafana 3000
```

Prometheus scrapes the API `/metrics` endpoint on the internal network.

## Vault

The bundled Vault runs in file-storage mode for bootstrap. For hardened production, initialize Vault properly and inject secrets via Vault Agent instead of `.env.prod`.
