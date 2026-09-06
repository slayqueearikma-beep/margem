# Tailscale and public HTTPS coexistence

Tailscale is for **administration only** (SSH, private dashboards). End users reach Dribex over the **public Internet**.

## Goal

```text
Tailscale          → SSH, optional private admin tools
Public Internet    → TCP 443 → Docker nginx → web + API
```

## If Tailscale Serve owns port 443

Symptoms:

- `sudo ss -lntp | grep ':443'` shows `tailscaled` instead of `docker-proxy`/`nginx`
- Public users cannot reach the site even when DNS is correct
- Nginx container may fail to bind `443:443`

### Diagnose

```bash
sudo ss -lntp | grep -E ':22|:80|:443'
tailscale serve status
tailscale funnel status
```

### Fix (preserve SSH)

Disable **only** the HTTPS serve/funnel listeners — not Tailscale itself:

```bash
# Reset Serve configuration (does not remove Tailscale or SSH)
tailscale serve reset
tailscale funnel reset 2>/dev/null || true

# Confirm nginx can bind 443
cd ~/MarGem/souq-local/infra/onprem
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d nginx
sudo ss -lntp | grep ':443'
```

Expected: `docker-proxy` or nginx process on `0.0.0.0:443`.

### SSH access after changes

Tailscale SSH (`tailscale ssh user@piocco`) and normal SSH over the Tailscale IP **continue to work** — Serve/Funnel reset does not disable Tailscale networking.

## Firewall

```bash
sudo ufw allow 22/tcp    # or restrict to Tailscale interface if preferred
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status verbose
```

Do **not** publicly expose `5432`, `6379`, `9000`, `8200`, `9090`, `3000`, or `8000`.

## DNS separation

| Audience | DNS target |
|----------|------------|
| Public users | Public IP (`196.117.33.109` or Cloudflare proxy) |
| Admin SSH | Tailscale hostname / `100.x.x.x` |

Never point `api.dribex.ma` public DNS at a Tailscale-only IP.
