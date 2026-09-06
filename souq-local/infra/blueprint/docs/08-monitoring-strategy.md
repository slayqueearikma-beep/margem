# Monitoring Strategy

## Observability stack

| Component | Purpose |
|-----------|---------|
| **Application Insights** | APM, dependency tracking, live metrics |
| **Log Analytics** | Central log store, KQL queries |
| **Container Insights** | AKS pod/node metrics |
| **Network Watcher** | Flow logs, connection troubleshoot |
| **Azure Monitor Alerts** | SLO-based paging |
| **Resource Health** | Platform outage awareness |

## Golden signals

| Signal | Metric | Alert threshold |
|--------|--------|-----------------|
| Latency | P95 API response | > 500ms for 5 min |
| Traffic | Requests/sec | Anomaly detection |
| Errors | 5xx rate | > 1% for 5 min |
| Saturation | CPU/memory pods | > 80% for 10 min |

## Dashboards

1. **Executive** — Availability, MAU, error budget
2. **API** — Endpoint latency, auth failures, rate limit hits
3. **Infrastructure** — AKS nodes, PG connections, Redis memory
4. **Security** — Failed logins, WAF blocks, Sentinel incidents
5. **FinOps** — Daily cost by tag

## Distributed tracing

- W3C `traceparent` from mobile (future) → APIM → FastAPI → PostgreSQL
- Application Insights automatic dependency correlation

## Log retention

| Log type | Retention | Tier |
|----------|-----------|------|
| Application | 90 days | Log Analytics |
| Audit / security | 365 days | Log Analytics + Sentinel |
| Access (APIM) | 90 days | Log Analytics |
| Kubernetes | 30 days | Container Insights |

Configurable via `monitoring.log_retention_days`.

## Availability tests

- Front Door synthetic tests: `/health` every 5 min from 3 regions
- APIM health probe: `/ready` every 30 sec
- Alert on 2 consecutive failures

## On-call

- P1: PagerDuty / Teams (API down, DB unreachable)
- P2: Slack (elevated errors, disk space)
- P3: Email (cost alerts, certificate expiry)

## Existing app compatibility

FastAPI already supports `APPLICATIONINSIGHTS_CONNECTION_STRING` (see `infra/terraform/main.tf`). Blueprint expands workspace retention and adds AKS/APIM diagnostics.
