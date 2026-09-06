# Phase 8 — Production Readiness

This document tracks Dribex production launch readiness after Phase 7 pre-production validation.

## Automated gate

Run from the repository root:

```bash
chmod +x scripts/phase8-production-readiness.sh
./scripts/phase8-production-readiness.sh
```

Optional live checks against a deployed stack:

```bash
API_URL=https://api.dribex.ma WEB_URL=https://dribex.ma ./scripts/phase8-production-readiness.sh
```

## Configuration separation

| Environment | Template | Notes |
|-------------|----------|-------|
| Local dev | `backend/.env.example` | localhost CORS/hosts allowed; manual billing OK |
| Docker dev | `.env.example`, `env.docker.example` | LAN/Tailscale URLs for device testing |
| Staging | `env.staging.example` | HTTPS only; NAPS sandbox; no localhost in CORS/hosts |
| Production | `env.production.example` | NAPS production; admin MFA required; no embedded admin |

Never commit `.env.production`, `.env.staging`, or `.env.home`.

## Security controls enforced at startup

When `APP_ENV` is `production`, `prod`, `staging`, `preprod`, or `preview`:

- `DEBUG=false`, `AUTH_DEV_BYPASS=false`
- JWT, upload-token, and MFA keys must be ≥32 chars and not placeholders
- `CORS_ORIGINS` and `ALLOWED_HOSTS` must not include `*`, localhost, or private IPs
- Brevo email required unless `ALLOW_INSECURE_EMAIL_FALLBACK=true` (break-glass only)
- `PUBLIC_APP_URL` and `PUBLIC_API_URL` must use HTTPS (except localhost/LAN)
- Production requires `ADMIN_IP_ALLOWLIST` and `ADMIN_REQUIRE_STAFF_MFA=true`
- `PAYMENT_PROVIDER=naps` required in production (no manual billing)
- OpenAPI (`/docs`, `/openapi.json`) disabled outside `development`/`dev`
- Validation error responses sanitized (no field-level leakage)

## Required production environment variables

See `env.production.example` for the full list. Critical secrets (server-only):

- `JWT_SECRET_KEY`, `UPLOAD_TOKEN_SECRET`, `MFA_ENCRYPTION_KEY`
- `DATABASE_URL`
- `BREVO_API_KEY`
- `NAPS_*` credentials
- `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`

Recommended for multi-instance deployments:

- `REDIS_URL` — shared rate-limit state across API replicas

## Database

- Migration chain is linear; CI validates fresh `alembic upgrade head`
- Do **not** reset or truncate production data during deployment
- Run migrations with a backup taken first

## Backups (production blocker until verified)

Scripts exist:

- `scripts/backup_home_db.sh`
- `infra/onprem/scripts/backup.sh`

Before go-live, verify on a non-production clone:

1. Automated backup schedule is configured
2. Backups are stored off the primary database host
3. Retention policy is defined
4. Restore procedure is documented and tested

## CORS and network

Production CORS must list only public HTTPS storefront origins, for example:

```text
CORS_ORIGINS=https://dribex.ma,https://www.dribex.ma
```

Do not include localhost, Tailscale IPs, or RFC1918 addresses in production/staging.

Admin APIs are additionally protected by:

- `ADMIN_IP_ALLOWLIST` (CIDR)
- Staff MFA (`ADMIN_REQUIRE_STAFF_MFA=true`)
- Separate admin dashboard container (`SERVE_EMBEDDED_ADMIN=false`)

## CI coverage

GitHub Actions (`margem-ci.yml`) runs:

- Backend tests, migration validation, bandit, pip-audit, gitleaks
- Production settings smoke test
- Web build, lint, and security tests
- Mobile analyze/test
- Terraform validate
- API Docker image build + Trivy scan

## Known blockers before public launch

These cannot be resolved in code alone:

| Blocker | Owner | Status |
|---------|-------|--------|
| Cloudflare tunnel / DNS live | Ops | Required |
| Backup restore tested | Ops | Required |
| NAPS production credentials on server | Ops | Required |
| Brevo production API key on server | Ops | Required |
| `REDIS_URL` for multi-replica API | Ops | Required if scaling |
| Staging soak with real payment sandbox flows | QA | Recommended |

## Deployment reference

- Production compose: `infra/onprem/docker-compose.prod.yml`
- Phase 7 validation: `scripts/phase7-validate.sh`, `docs/PHASE7_PREPRODUCTION_VALIDATION.md`
- Cloudflare templates: `infra/cloudflare/`

## Post-launch monitoring

- `/health` and `/ready` for load balancer probes
- `/metrics` restricted to internal networks only
- Configure `SENTRY_DSN` for error tracking
