# Cloudflare Tunnel — production edge

Expose the API through Cloudflare without opening router ports for HTTP/SSH.

## Architecture

```text
Internet → Cloudflare (HTTPS, WAF, rate limit) → cloudflared tunnel → nginx:443 → API:8000
```

## DNS (example)

| Host | Type | Target |
|------|------|--------|
| `api.dribex.ma` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `qr.dribex.ma` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `dribex.ma` | CNAME | `<tunnel-id>.cfargotunnel.com` |

Route `qr.dribex.ma` to the same API — the `/p/{token}` handler serves public QR resolution.

## Setup

1. Create a tunnel in Cloudflare Zero Trust dashboard.
2. Copy `config.yml.example` to `/etc/cloudflared/config.yml`.
3. Place tunnel credentials JSON from Cloudflare.
4. Run: `cloudflared tunnel run dribex-prod`

## Do NOT expose publicly

- PostgreSQL (5432)
- MinIO console (9001)
- Redis (6379)
- Grafana/Prometheus (internal VPN only)
- SSH (use Cloudflare Access or VPN)

## Security

- Enable Cloudflare WAF managed rules
- Rate limit `/auth/*` and `/uploads/*`
- Bot Fight Mode on `api.dribex.ma`
- Full (strict) SSL mode
- HSTS via Cloudflare + backend `SecurityHeadersMiddleware`
