# Scaling Strategy

## Horizontal scaling path

| Users (MAU) | Compute | Database | Cache | Edge |
|-------------|---------|----------|-------|------|
| < 1k | Home server / Container Apps | Single PG B1ms | None | Direct URL |
| 1k–50k | AKS 2–5 pods | PG GP 2 vCore | Redis Basic | Front Door |
| 50k–500k | AKS 10–50 pods HPA | PG HA + 1 read replica | Redis Standard | Front Door + CDN |
| 500k–5M | Multi-region AKS | PG + sharding prep | Redis Premium cluster | Active-active FD |
| 5M+ | Service mesh, cell architecture | Citus / shard by city | Redis cluster | Global anycast |

## AKS autoscaling

```yaml
# HPA example (kubernetes/hpa-api.yaml.example)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: margem-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: margem-api
  minReplicas: 3
  maxReplicas: 100
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**Cluster Autoscaler:** Scales node pools when pods are unschedulable.

**KEDA (optional):** Scale workers on Service Bus queue depth.

## Node pools

| Pool | VM SKU | Purpose | Scaling |
|------|--------|---------|---------|
| `system` | D2s_v5 | System pods | Fixed 2–3 nodes |
| `api` | D4s_v5 | API workloads | 3–50 nodes, cluster autoscaler |
| `workers` | D2s_v5 | Background jobs | 0–20 nodes, spot optional |
| `gpu` (dormant) | NC-series | AI inference | `module_flags.ai` |

## Database scaling

1. **Vertical:** Increase vCores (no app change)
2. **Read replicas:** Route read-heavy endpoints (`/sellers`, `/search`) — requires read connection string env var (future)
3. **Connection pooling:** PgBouncer sidecar or Azure built-in pooler
4. **Sharding (future):** Shard key = `city` (Casablanca first, expand per city)

## Caching layers

| Layer | Data |
|-------|------|
| CDN (Front Door) | Static assets, public seller images |
| APIM cache | GET `/categories`, `/sellers` list |
| Redis | Sessions, rate limits, search results (60s TTL) |
| App in-memory | Avoid — all replicas must be stateless |

## Performance optimizations (no logic change)

- Enable gzip/brotli at Front Door
- Image CDN for blob media
- PostgreSQL query indexes (existing migrations)
- Async email/upload via Service Bus (Phase 3)

## Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: margem-api
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: margem-api
```

## Load testing gates

Before enabling autoscaling in production:

- k6 / Azure Load Testing: 10k RPS sustained on `/health`, `/sellers`, `/search`
- Verify HPA scales within 2 minutes
- Verify PostgreSQL connection pool does not exhaust
