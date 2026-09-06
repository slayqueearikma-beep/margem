# Public TLS setup for Dribex production

Ordinary Android/iOS devices **reject self-signed** certificates. Public production requires a **trusted** TLS certificate on nginx.

## Option A — Cloudflare proxy + Origin Certificate (recommended)

Use when `dribex.ma` DNS is proxied through Cloudflare (orange cloud).

### 1. Cloudflare DNS

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `YOUR_PUBLIC_IP` | Proxied |
| A | `www` | `YOUR_PUBLIC_IP` | Proxied |
| A | `api` | `YOUR_PUBLIC_IP` | Proxied |

Do **not** point public DNS at Tailscale IPs (`100.x.x.x`).

### 2. Create Origin Certificate

Cloudflare Dashboard → **SSL/TLS** → **Origin Server** → **Create Certificate**

Hostnames:

```text
api.dribex.ma
dribex.ma
www.dribex.ma
*.dribex.ma
```

Key type: **RSA 2048**

### 3. Install on the server

```bash
cd ~/MarGem/souq-local/infra/onprem/nginx/certs

# Backup old bootstrap certs (optional)
mkdir -p ~/cert-backup-$(date +%Y%m%d)
cp -a fullchain.pem privkey.pem ~/cert-backup-$(date +%Y%m%d)/ 2>/dev/null || true

# Replace only the two PEM files — keep the certs/ directory
nano fullchain.pem   # paste Origin Certificate
nano privkey.pem     # paste Private Key

chmod 644 fullchain.pem
chmod 600 privkey.pem
```

### 4. Cloudflare SSL mode

**SSL/TLS** → **Overview** → **Full (strict)**

### 5. Restart nginx

```bash
cd ~/MarGem/souq-local/infra/onprem
docker compose -f docker-compose.prod.yml --env-file .env.prod restart nginx
```

### 6. Verify

```bash
curl -fsS https://api.dribex.ma/ready
openssl s_client -connect api.dribex.ma:443 -servername api.dribex.ma </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates
```

---

## Option B — Let's Encrypt (direct to server)

Use when nginx is the public TLS endpoint **without** Cloudflare proxy.

Requirements:

- Public DNS A records → your public IP
- Ports `80` and `443` open on the public interface
- Tailscale Serve must **not** own port 443 (see `docs/TAILSCALE_PUBLIC_COEXISTENCE.md`)

Example with certbot standalone (brief nginx downtime):

```bash
cd ~/MarGem/souq-local/infra/onprem
docker compose -f docker-compose.prod.yml --env-file .env.prod stop nginx

sudo certbot certonly --standalone \
  -d api.dribex.ma -d dribex.ma -d www.dribex.ma \
  --agree-tos -m admin@dribex.ma

sudo cp /etc/letsencrypt/live/api.dribex.ma/fullchain.pem nginx/certs/fullchain.pem
sudo cp /etc/letsencrypt/live/api.dribex.ma/privkey.pem nginx/certs/privkey.pem
sudo chmod 644 nginx/certs/fullchain.pem
sudo chmod 600 nginx/certs/privkey.pem

docker compose -f docker-compose.prod.yml --env-file .env.prod up -d nginx
```

Renewal: add a cron job for `certbot renew` and nginx reload.

---

## What NOT to use in production

| Approach | Public mobile? |
|----------|----------------|
| Bootstrap self-signed (`deploy.sh` auto-gen) | No |
| `ALLOW_INSECURE_TLS=true` in mobile | No — private beta only |
| Tailscale IP in public DNS | No |
| Cloudflare Origin cert **without** Cloudflare proxy | No — not in device trust stores |
