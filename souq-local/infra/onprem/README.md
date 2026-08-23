# MarGem On-Prem Production (Ubuntu)

Production Docker Compose stack for self-hosted deployment on Ubuntu.

## Architecture

```
Internet → nginx (443) → FastAPI API
                ↓
    PostgreSQL | Redis | MinIO | Vault (internal network only)
                ↓
    Prometheus | Loki | Grafana (internal — access via SSH tunnel)
```

Only **nginx** exposes ports 80/443. All other services are on an internal Docker network.

## Quick start

```bash
cd infra/onprem
cp env.prod.example .env.prod
# Edit secrets, domain URLs, SMTP, Stripe

./scripts/deploy.sh
```

Place TLS certificates in `nginx/certs/fullchain.pem` and `privkey.pem` (Let's Encrypt recommended).

## Backups

```bash
./scripts/backup.sh          # PostgreSQL dump + MinIO mirror
./scripts/restore.sh /var/backups/margem/postgres-YYYYMMDD.sql.gz
```

Schedule `backup.sh` via cron. Store backups off-server.

## Storage

Set `STORAGE_BACKEND=minio` in the API environment (configured in `docker-compose.prod.yml`).

`MINIO_PUBLIC_URL` should match the nginx `/storage/` proxy path.

## Monitoring

Grafana is internal-only. Access via SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 user@your-server
docker compose -f docker-compose.prod.yml --env-file .env.prod port grafana 3000
```

## Vault

The bundled Vault runs in file-storage mode for bootstrap. For production, initialize Vault properly, enable auto-unseal, and inject secrets via Vault Agent instead of `.env.prod`.

## Legal pages

Terms and privacy are served at `/terms` and `/privacy` by the API.
