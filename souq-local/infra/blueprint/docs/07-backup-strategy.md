# Backup Strategy

## PostgreSQL Flexible Server

| Setting | Production value |
|---------|------------------|
| Backup retention | 35 days |
| Geo-redundant backup | Enabled |
| PITR | Continuous |
| Long-term retention | Optional 1-year vault (compliance) |

**Restore test:** Monthly restore to isolated server, run `pytest` smoke suite.

## Blob Storage

| Feature | Setting |
|---------|---------|
| Replication | GRS (geo-redundant) |
| Soft delete | 30 days |
| Versioning | Enabled |
| Immutable policy | WORM for audit bucket (optional) |
| Lifecycle | Move to Cool after 90 days, Archive after 365 |

## Key Vault

- Soft delete: 90 days
- Purge protection: enabled in production
- Backup: Azure Backup for Key Vault (optional module flag)

## Kubernetes

- **Velero** (documented, not auto-installed): cluster state + PV snapshots
- Stateless API: redeploy from ACR sufficient for app tier

## Terraform state

- Remote backend with versioning (Azure Storage)
- State locking via blob lease
- Separate state per environment

## Backup schedule summary

| Asset | Frequency | Retention |
|-------|-----------|-----------|
| PostgreSQL PITR | Continuous | 35 days |
| PostgreSQL weekly export | Weekly | 90 days (blob) |
| Blob versions | Per change | 30 days soft delete |
| Key Vault | Daily | 90 days |
| Terraform state | Per apply | 90 days versioning |

## Home server migration note

When migrating from `docker-compose.home.yml`, use `scripts/restore_home_backup.sh` into blueprint PostgreSQL before cutover.
