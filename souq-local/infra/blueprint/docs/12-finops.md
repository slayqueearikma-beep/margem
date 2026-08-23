# FinOps & Cost Optimization

## Tagging strategy (mandatory)

All blueprint resources receive:

```hcl
tags = {
  project     = "margem"
  environment = var.environment_name
  cost_center = "engineering"
  owner       = "platform-team"
  blueprint   = "enterprise"
  phase       = var.activation_phase
}
```

## Cost controls

| Control | Implementation |
|---------|----------------|
| Budget alerts | Azure Budget at 50%, 80%, 100% of monthly cap |
| Autoscaling | AKS HPA + cluster autoscaler; scale to zero workers off-peak |
| Spot nodes | Worker node pool `spot_enabled = true` (non-critical jobs) |
| Reserved capacity | 1-year RI for baseline AKS nodes after 3 months stable usage |
| Storage lifecycle | Hot → Cool → Archive for old media |
| Log retention | 30 days dev, 90 days prod (not infinite) |
| DDoS / Premium SKUs | Disabled in dev/staging via `module_flags` |

## Module cost tiers

| Module | Dev (off) | Staging | Production |
|--------|-----------|---------|------------|
| networking | $0 | ~$50 (NAT) | ~$200 (NAT + Bastion) |
| postgresql | $0 | ~$80 | ~$400 (HA) |
| aks | $0 | ~$150 | ~$800–2000 |
| frontdoor | $0 | ~$35 | ~$100+ |
| apim | $0 | ~$50 (Consumption) | ~$700 (Standard) |
| redis | $0 | ~$30 | ~$150 |
| monitoring | $0 | ~$20 | ~$100 |
| defender | $0 | optional | ~$200 |

**Dormant blueprint:** **$0/month**

## Right-sizing guidance

1. Start with **Consumption APIM** in staging; upgrade to Standard at 10k+ RPS
2. PostgreSQL: begin `GP_Standard_D2s_v3`, scale on CPU > 70%
3. AKS: 3× `Standard_D4s_v5` API nodes handle ~5k RPS for Dribex's API profile
4. Disable `module_flags.ai` and `module_flags.search` until product requires them

## Cost dashboards

- Azure Cost Management + Billing → filter `tag:project=margem`
- Weekly FinOps review: top 5 resources by cost
- Anomaly alerts on daily spend

## Comparison to current stack

| Stack | Est. monthly |
|-------|--------------|
| Home server (electricity + internet) | ~$10–30 |
| `infra/terraform` Container Apps | ~$50–90 |
| Blueprint pilot (Phase 1–2) | ~$800–1500 |
| Blueprint full production | ~$3000–8000 |

**Do not activate blueprint until revenue or user growth justifies operational cost.**

## Savings recommendations

- Use **Azure Hybrid Benefit** if Windows licenses available (N/A for Linux AKS)
- **Dev/Test** pricing for non-production subscriptions
- **Shutdown staging** nights/weekends via automation runbook
- **Compress** API responses at Front Door (reduce egress)
