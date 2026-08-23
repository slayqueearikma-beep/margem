# MarGem Azure Enterprise Scalability Blueprint

> **Status: DORMANT** — This directory is a **future-ready infrastructure blueprint**. It is **not** connected to the running application, CI/CD, or home-server deployment. **Do not `terraform apply` here** unless you are intentionally migrating to enterprise scale.

## Purpose

Define production-grade Azure infrastructure capable of scaling MarGem from hundreds to millions of users **without a major redesign**, while preserving:

- All existing APIs and business logic
- PostgreSQL schema and Alembic migrations
- JWT authentication flow
- Flutter mobile client contracts
- Azure Blob upload paths

## Current vs future

| Layer | **Today (unchanged)** | **Blueprint (when activated)** |
|-------|----------------------|--------------------------------|
| Compute | Docker home server / `infra/terraform` Container Apps | AKS + optional App Service bridge |
| Database | PostgreSQL 16 (single instance) | PostgreSQL Flexible Server HA + read replicas |
| Edge | Direct API URL / optional Cloudflare tunnel | Azure Front Door Premium + WAF + CDN |
| API gateway | FastAPI built-in rate limits | Azure API Management |
| Cache | In-memory / optional Redis URL | Azure Cache for Redis (private) |
| Messaging | Synchronous (email, uploads) | Service Bus + Event Grid workers |
| Search | PostgreSQL `ILIKE` on `/search` | Azure AI Search (optional module) |
| Secrets | `.env` / Key Vault (basic terraform) | Key Vault + Managed Identity + rotation |
| Monitoring | Docker logs / App Insights (basic) | Full observability stack |
| IaC | `infra/terraform`, `terraform-budget` | This blueprint (`infra/blueprint/terraform`) |

## Activation policy

1. **Default:** `blueprint_enabled = false` — **zero Azure resources** created.
2. **Workspace:** Use Terraform workspace `margem-enterprise-blueprint` (separate state from `infra/terraform`).
3. **Phases:** Enable modules incrementally via `module_flags` (see `terraform/variables.tf`).
4. **No app changes required** until Phase 2 (APIM routing) or Phase 3 (async workers).

## Documentation index

| Document | Description |
|----------|-------------|
| [docs/01-architecture-overview.md](docs/01-architecture-overview.md) | High-level system design |
| [docs/02-network-topology.md](docs/02-network-topology.md) | VNet, subnets, NSGs, Private Link |
| [docs/03-data-flow.md](docs/03-data-flow.md) | Request and async data paths |
| [docs/04-security-architecture.md](docs/04-security-architecture.md) | Zero Trust, identity, Defender |
| [docs/05-deployment-architecture.md](docs/05-deployment-architecture.md) | CI/CD, deployment strategies |
| [docs/06-disaster-recovery.md](docs/06-disaster-recovery.md) | RTO/RPO, failover, multi-region |
| [docs/07-backup-strategy.md](docs/07-backup-strategy.md) | DB, blob, Key Vault backups |
| [docs/08-monitoring-strategy.md](docs/08-monitoring-strategy.md) | Metrics, logs, alerts, tracing |
| [docs/09-scaling-strategy.md](docs/09-scaling-strategy.md) | HPA, cluster autoscaler, FinOps |
| [docs/10-security-checklist.md](docs/10-security-checklist.md) | Pre-production security gates |
| [docs/11-migration-path.md](docs/11-migration-path.md) | Step-by-step from current stack |
| [docs/12-finops.md](docs/12-finops.md) | Cost controls and tagging |

## Terraform

```bash
cd souq-local/infra/blueprint/terraform

# NEVER apply on production subscription without review
cp environments/production.tfvars.example environments/production.tfvars

terraform init -backend-config=backends/local.backend.hcl.example
terraform workspace new margem-enterprise-blueprint
terraform plan -var-file=environments/production.tfvars
# blueprint_enabled defaults to false → plan shows 0 resources
```

## Estimated cost when fully enabled (production)

| Tier | Monthly range (EUR) | Users |
|------|---------------------|-------|
| Dormant | $0 | — |
| Pilot (network + DB + 1 AKS node pool) | ~$800–1,500 | 1k–10k |
| Production (HA, Front Door, APIM, Redis) | ~$3k–8k | 10k–500k |
| Multi-region active-active | ~$12k+ | 500k–5M+ |

Use `module_flags` to enable only what you need. See [docs/12-finops.md](docs/12-finops.md).

## Relationship to existing infra

- `infra/terraform/` — **Active** small-scale Azure (Container Apps). Keep using this.
- `infra/terraform-budget/` — **Active** single-VM budget option.
- `docker-compose.home.yml` — **Active** home server. Unaffected.
- `infra/blueprint/` — **Dormant** enterprise design only.
