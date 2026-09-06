# Docker network hardening — Dribex production

Defense-in-depth for Docker published ports on Ubuntu + UFW + Cloudflare + Tailscale.

## Repository audit (canonical production compose)

`infra/onprem/docker-compose.prod.yml` is already hardened:

| Service | Host `ports:` | Network |
|---------|---------------|---------|
| nginx | `80`, `443` only | `internal` + `edge` |
| api, web, postgres, redis, minio, vault, prometheus, grafana, loki | **none** | `internal` (`internal: true`) |

Nginx proxies to `api:8000` and `web:3000` on the Docker network. **No router forwarding** should exist for backend ports.

If your live server still shows `0.0.0.0:8000`, `0.0.0.0:5432`, etc., you are likely running an old compose file, a manual override, or a dev compose. Fix the running stack before relying on firewall rules alone.

---

## Step 1 — Audit (read-only)

On the server:

```bash
cd ~/MarGem/souq-local/infra/onprem
chmod +x scripts/audit-docker-exposure.sh
./scripts/audit-docker-exposure.sh
```

Review the output. Expected `docker ps` ports column:

```text
nginx   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

All other services should show **no** `0.0.0.0` mappings.

---

## Step 2 — Fix compose (if audit shows extra ports)

```bash
cd ~/MarGem/souq-local/infra/onprem
git pull
./scripts/validate-compose-ports.sh

docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

Remove any local `docker-compose.override.yml` that publishes internal ports.

**Tailscale-only API (optional):** use `docker-compose.tailscale-admin.override.example.yml` with `TAILSCALE_IP=$(tailscale ip -4)` — never `0.0.0.0:8000:8000`.

---

## Step 3 — DOCKER-USER (defense in depth)

Docker bypasses UFW for published ports. `DOCKER-USER` blocks accidental exposure if someone adds a `ports:` mapping later.

**Keep your current SSH session open.** Open a second Tailscale SSH session before closing the first.

```bash
cd ~/MarGem/souq-local/infra/onprem
sudo chmod +x scripts/harden-docker-user.sh scripts/rollback-docker-user.sh

# 1. Audit (read-only):
./scripts/audit-docker-exposure.sh

# 2. Preview (no changes):
sudo DRY_RUN=1 CONFIRM=1 ./scripts/harden-docker-user.sh

# 3. Apply in memory only (safe — reboot clears unless you persist):
sudo CONFIRM=1 ./scripts/harden-docker-user.sh

# 4. After verifying HTTPS works, persist across reboot:
sudo CONFIRM=1 PERSIST_RULES=1 ./scripts/harden-docker-user.sh
```

**Lab with extra published ports** (only if you know what you're doing):

```bash
sudo CONFIRM=1 ALLOW_EXTRA_PORTS=7215 ./scripts/harden-docker-user.sh
```

Rollback:

```bash
sudo CONFIRM=1 ./scripts/rollback-docker-user.sh
```

Persist after successful test:

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

---

## Step 4 — UFW (do not blindly change)

Your setup is correct if:

- `default: deny (incoming)`
- SSH allowed on `tailscale0` only (not `allow 22/tcp` globally)
- Admin `7215` / API `8000` allowed on `tailscale0` only
- **Do not** add `ufw allow 80` / `443` unless you understand Docker/UFW interaction — published nginx ports work via Docker DNAT + `DOCKER-USER`

---

## Step 5 — Router

Internet must forward **only**:

```text
80  → 192.168.11.103
443 → 192.168.11.103
```

No forwarding for `22`, `7215`, `8000`, `5432`, `6379`, `9000`, `9090`, `8200`, `3100`.

---

## Verification commands

```bash
sudo docker ps --format "table {{.Names}}\t{{.Ports}}"
sudo ss -lntup
sudo iptables -L DOCKER-USER -n -v --line-numbers
sudo iptables -t nat -L DOCKER -n -v --line-numbers | head -40
sudo iptables -L FORWARD -n -v | head -30
sudo ufw status verbose
./scripts/validate-compose-ports.sh
curl -fsS https://api.dribex.ma/ready
```

---

## External Nmap (from another network — not LAN, not Tailscale)

Replace `YOUR_PUBLIC_IP` with your home public IP (or scan by hostname through Cloudflare):

```bash
nmap -Pn -p 22,80,443,7215,8000,5432,6379,9000,9090,8200,3100 YOUR_PUBLIC_IP
```

Or via DNS (tests Cloudflare path):

```bash
nmap -Pn -p 22,80,443,7215,8000,5432,6379,9000,9090,8200,3100 api.dribex.ma dribex.ma
```

**Expected from the Internet:**

| Port | Expected |
|------|----------|
| 80 | open |
| 443 | open |
| 22, 7215, 8000, 5432, 6379, 9000, 9090, 8200, 3100 | closed or filtered |

Note: scanning `api.dribex.ma` through Cloudflare may show Cloudflare edge on 80/443 only — that is correct.

---

## Production verdict (repository)

```text
SECURE ENOUGH FOR NEXT TEST
```

…**after** you confirm the live server matches `docker-compose.prod.yml` (nginx only published) and apply `DOCKER-USER` hardening.

If audit still shows `0.0.0.0:5432` or similar:

```text
NOT READY — FIX REQUIRED
```

Remove those port mappings first; firewall rules are not a substitute.
