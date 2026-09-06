# Security Checklist

Use before activating each blueprint phase in production.

## Identity & access

- [ ] Entra ID Conditional Access enabled for all admins (MFA)
- [ ] Privileged Identity Management (PIM) for Owner/Contributor roles
- [ ] No shared admin accounts
- [ ] AKS RBAC integrated with Entra ID
- [ ] Workload Identity configured for API pods
- [ ] Service principals use certificate auth, not client secrets

## Network

- [ ] PostgreSQL public access disabled
- [ ] Storage public access disabled
- [ ] Key Vault public access disabled
- [ ] NSGs applied to all subnets
- [ ] Front Door restricts origin to APIM only
- [ ] DDoS Protection enabled on production VNet
- [ ] Bastion used for admin access (no public SSH)

## Secrets

- [ ] No secrets in Git (Gitleaks clean)
- [ ] JWT secret ≥ 32 chars, stored in Key Vault
- [ ] Key Vault purge protection enabled
- [ ] Secret rotation calendar documented
- [ ] Terraform state encrypted, no secrets in plain text

## Application (unchanged code, config only)

- [ ] `AUTH_DEV_BYPASS=false`
- [ ] `DEBUG=false`
- [ ] `CORS_ORIGINS` has no wildcard
- [ ] `ALLOWED_HOSTS` restricted to API FQDN
- [ ] Rate limits configured (APIM + app)
- [ ] TLS 1.2+ only

## Container & supply chain

- [ ] Images scanned (Trivy) with no critical CVEs
- [ ] Images signed (Cosign)
- [ ] SBOM generated and stored
- [ ] ACR admin user disabled
- [ ] Only trusted base images (`python:3.12-slim`)

## Monitoring & response

- [ ] Defender for Cloud plans enabled
- [ ] Sentinel analytics rules active
- [ ] Failed login alerts configured
- [ ] WAF in Prevention mode (after tuning)
- [ ] Incident response runbook documented

## Compliance

- [ ] Azure Policy initiatives assigned (CIS, ISO 27001 optional)
- [ ] Audit logs retained ≥ 90 days
- [ ] Data processing agreement for EU regions
- [ ] Privacy policy covers data residency

## Pre-cutover

- [ ] Penetration test completed
- [ ] DR drill completed
- [ ] Backup restore validated
- [ ] Rollback procedure tested
