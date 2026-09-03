# Public network access for mobile beta

If the mobile app shows **"Cannot reach the API at https://api.dribex.ma"** during signup or login, the phone cannot reach your API over the public Internet.

## Root cause (most common)

`api.dribex.ma` DNS points to a **Tailscale IP** (`100.x.x.x`). Only devices on your Tailscale network can reach that address. Normal phones on mobile data or home Wi‑Fi **cannot**.

Check from any machine:

```bash
getent ahostsv4 api.dribex.ma
```

If you see `100.80.x.x` or similar → fix DNS (below).

## Fix checklist (server operator)

### 1. DNS — point to your **public** IP

At your domain registrar or Cloudflare:

| Record | Type | Value |
|--------|------|-------|
| `api` | A | `YOUR_PUBLIC_IP` (e.g. `196.117.33.109`) |
| `@` | A | `YOUR_PUBLIC_IP` |
| `www` | A or CNAME | `YOUR_PUBLIC_IP` or `dribex.ma` |

**Do not** use `100.x.x.x` (Tailscale) in public DNS.

Wait for propagation (minutes to hours), then verify:

```bash
getent ahostsv4 api.dribex.ma   # must NOT be 100.x.x.x
```

### 2. Firewall — allow HTTPS on the public interface

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

Tailscale-only rules are fine for SSH, but **443 must be reachable from the Internet** for public beta.

### 3. Nginx — listen on all interfaces

In `docker-compose.prod.yml`, nginx ports should be:

```yaml
ports:
  - "80:80"
  - "443:443"
```

**Not** bound only to `100.80.43.124:443`.

Restart:

```bash
cd ~/MarGem/souq-local/infra/onprem
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d nginx
```

### 4. TLS — trusted certificate (required for mobile)

Mobile apps **reject self-signed** certificates. Replace bootstrap certs in `nginx/certs/` with either:

- **Cloudflare Origin Certificate** (recommended if using Cloudflare proxy), or
- **Let's Encrypt** (`certbot certonly --standalone` or DNS challenge)

Files:

- `nginx/certs/fullchain.pem`
- `nginx/certs/privkey.pem`

### 5. Verify from mobile data (no VPN)

On a phone **without Tailscale**, open:

```
https://api.dribex.ma/ready
```

Should return JSON with HTTP 200.

Or run on a machine without Tailscale:

```bash
cd infra/onprem
./scripts/verify-public-api.sh
```

### 6. Rebuild the mobile app for production

```bash
cd mobile
flutter build apk \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=https://api.dribex.ma
```

Or use `scripts/build-production-android.sh`.

## Temporary private beta (Tailscale only)

If you are **not** ready for public DNS yet:

1. Install **Tailscale** on the test phone (same account as the server).
2. Point `api.dribex.ma` / `dribex.ma` to the server Tailscale IP (`100.x.x.x`) via phone hosts, Tailscale DNS, or split DNS.
3. Confirm in the phone browser: `https://api.dribex.ma/ready` → HTTP 200 JSON.

**Why the app fails when the browser works:** Chrome may let you accept a self-signed certificate; the Flutter HTTP client rejects it by default.

### Private beta mobile build (self-signed nginx cert)

Do **not** use `PRODUCTION=true` for Tailscale testing. Rebuild with insecure TLS allowed:

```bash
cd mobile
flutter run \
  --dart-define=API_BASE_URL=https://api.dribex.ma \
  --dart-define=ALLOW_INSECURE_TLS=true
```

Or install a debug APK:

```bash
./scripts/build-private-beta-android.sh
```

`ALLOW_INSECURE_TLS` is ignored when `PRODUCTION=true`. For real launch, use a **trusted** cert (Cloudflare Origin or Let's Encrypt) and the public DNS path above.

## Tailscale vs public

| Mode | DNS target | Who can use the app |
|------|------------|---------------------|
| Private beta | `100.x.x.x` | Tailscale devices only |
| Public beta | Public IP | Anyone in Morocco |

Keep Tailscale for **SSH/admin**; do not require Tailscale for normal users.
