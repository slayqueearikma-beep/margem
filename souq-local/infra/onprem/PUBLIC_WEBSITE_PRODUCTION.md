# Public website production architecture

This document describes how the **public customer website** (`dribex.ma` / Next.js `web` service) is separated from private seller and admin functionality for production launch.

## Public website scope (browse-only)

The public website is intentionally **read-only** for customers:

- Homepage, product/service listings, seller profiles, categories, cities, search, and listing detail pages
- Platform advertisement display (images/videos, impressions, click-through)
- Legal pages (`/terms`, `/privacy`, `/cookies`)

It does **not** include:

- Customer login, registration, messaging, favorites, community/chat
- Payments or subscriptions on the public storefront
- Seller listing creation/editing or image uploads
- Admin dashboards or operator tools

## API proxy boundaries

Browser traffic uses a hardened same-origin proxy at `/api-proxy/*`.

| Namespace | Public proxy | Seller proxy (`/api/seller/*`) |
|-----------|--------------|--------------------------------|
| `categories`, `search`, `products`, `services`, `sellers`, `marketplaces` | GET/HEAD only | — |
| `media/`, `brand/` | GET/HEAD only | — |
| `ads/active`, `ads/click/{id}`, `ads/media/{id}/{image\|video}` | GET/HEAD only | — |
| `ads/impressions` | **POST only** (strict JSON body limit) | — |
| `auth/`, `admin/`, `uploads/`, `billing/`, `community/` | **Blocked** | Partially allowed on seller route |

Content Security Policy keeps `img-src` and `media-src` same-origin. Listing and advertisement media are served through `/api-proxy/media/...` or `/api-proxy/ads/media/{campaign_id}/{kind}` — never by widening CSP to arbitrary third-party hosts.

## Advertisement operations (H6)

Production compose (`docker-compose.prod.yml`) sets `SERVE_EMBEDDED_ADMIN=false` and does **not** publish the admin dashboard on the public internet.

Operators manage advertisement campaigns through one of these **private** paths:

1. **SSH tunnel + admin API** (recommended)
   - Connect to the production host over SSH/VPN
   - Call `POST/PATCH /admin/advertisements` on the internal API (`http://api:8000` or nginx upstream) with an admin JWT and MFA when enabled
   - Admin routes require authentication, role checks, and production IP allowlists

2. **Optional admin-dashboard container** (not in default prod stack)
   - Run `admin-dashboard` on an internal network only
   - Access via SSH port-forward, never expose port 80/443 publicly for admin UI

3. **Direct database changes** — not recommended; use the admin API for auditability

Store ad creatives in MinIO (`/media/...` URLs) when possible so the public site uses the existing media proxy. External HTTPS creative URLs are proxied through `GET /ads/media/{campaign_id}/image|video` with server-side fetching only.

## Seller functionality (H1)

Seller registration, listing management, and authenticated image uploads remain **outside** the public customer website:

- **Mobile app** — primary seller workflow (unchanged)
- **Private seller web portal** (`/seller/*` on the web app) — separate from the public browse surface; uses `/api/seller/*`, not `/api-proxy`
- The public listing editor does not implement presign/upload flows by design

## Authentication boundaries (H4)

- The public browse website has **no customer authentication** and **no MFA**
- Seller/admin authentication (including MFA when configured) applies only to private routes (`/seller/*`, `/admin/*`, mobile API clients)
- MFA challenges on seller login are handled in the private seller portal, not on public catalog pages

## Launch configuration preserved

- Casablanca-only launch cities (`NEXT_PUBLIC_LAUNCH_CITIES`)
- Advertisement-only monetization (`ADS_ENABLED=true`, payments/subscriptions disabled)
- Listing video removed (`043_remove_listing_video` migration); platform ad video creatives remain supported

## Operator checklist before go-live

See `env.prod.example` and `scripts/validate-production-env.sh` for required secrets and service configuration (TLS, MinIO, Brevo, database migrations, admin IP allowlist).
