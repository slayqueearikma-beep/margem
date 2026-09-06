# Migration Path

## Guiding principle

**Zero downtime, zero API breakage.** Mobile app continues using same JSON schemas. Migrate infrastructure in phases; application code changes are optional until Phase 3+.

## Phase 0 — Today (no action)

- Home server: `docker-compose.home.yml`
- Or small Azure: `infra/terraform` (Container Apps)
- Budget VM: `infra/terraform-budget`

**Blueprint:** `blueprint_enabled = false`

## Phase 1 — Secure foundation (~2–4 weeks engineering)

**Enable modules:** `networking`, `keyvault`, `postgresql`, `storage`, `monitoring`

1. `terraform apply` with `module_flags` for Phase 1 only
2. Restore home backup into private PostgreSQL
3. Migrate blob media to GRS storage account
4. Point Container Apps / home API to private endpoints (VPN or temporary public with firewall)
5. Validate: all existing pytest + mobile smoke tests pass

**App changes:** Environment variables only (`DATABASE_URL`, `AZURE_STORAGE_*` via MI)

## Phase 2 — Scalable compute & edge (~4–6 weeks)

**Enable modules:** `aks`, `redis`, `apim`, `frontdoor`

1. Deploy same `margem-api` container to AKS (3 replicas)
2. Configure APIM to proxy all routes (`/auth/*`, `/sellers/*`, `/search`, etc.)
3. Front Door → APIM → AKS
4. Enable Redis, set `REDIS_URL` for distributed rate limiting
5. Update mobile `API_BASE_URL` to Front Door FQDN
6. Decommission Container Apps after 2-week parallel run

**App changes:** None (same API paths behind APIM)

## Phase 3 — Async workers (~2–3 weeks)

**Enable modules:** `servicebus`, `messaging`

1. Deploy worker Deployments (email, image processing)
2. Feature flag `ASYNC_JOBS=true` on API (future PR — not in blueprint)
3. Gradual rollout: 10% → 100% async email

**App changes:** Optional queue publish behind feature flag

## Phase 4 — Search at scale (optional)

**Enable modules:** `search`

1. Index sellers/products from PostgreSQL
2. APIM routes `/search` to AI Search OR API proxies (preserves mobile contract)

## Phase 5 — Multi-region

**Enable:** DR region module flags, Front Door active-active

## Rollback at any phase

| Phase | Rollback |
|-------|----------|
| 1 | Revert DNS/env to old database |
| 2 | Point mobile to Container Apps URL |
| 3 | `ASYNC_JOBS=false` |
| 4 | API uses PostgreSQL search only |
| 5 | Front Door single-origin |

## Compatibility matrix

| Endpoint | Preserved |
|----------|-----------|
| `POST /auth/register` | Yes |
| `POST /auth/login` | Yes |
| `GET /search` | Yes (schema unchanged) |
| `GET /sellers/map` | Yes |
| `POST /uploads/*` | Yes |
| JWT format | Yes |

## Terraform workspace migration

```bash
# Never import into production blueprint workspace without backup
terraform workspace select margem-enterprise-blueprint
terraform import -var-file=environments/staging.tfvars ...
```

See existing `infra/terraform/scripts/rotate-subscription.ps1` for subscription migration patterns.
