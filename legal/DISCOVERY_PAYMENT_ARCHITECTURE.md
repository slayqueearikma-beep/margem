# Discovery-Only Payment Architecture

This document is the deliverable for Dribex's payment architecture audit and redesign.
It describes what existed, what changed, and what remains regulated.

## 1. Old payment architecture

| Layer | Previous state |
|-------|----------------|
| Marketplace checkout | Built in migration `006_marketplace_production` (`orders`, `cart_items`, `payment_status`, coupons) |
| Removal | Migration `007_discovery_platform` **dropped** all ecommerce tables and enums |
| Stripe | **Removed** — was optional; fully migrated to NAPS |
| Subscriptions | Manual dev activation (`provider=manual`); blocked in production; admin grant |
| Seller payouts | **Never existed** |
| Mobile checkout | **Never existed** — legacy l10n strings remapped to “Contact seller” / “Favorites” |

Historical buyer→Dribex→seller flow was removed before this redesign. No Stripe Connect or seller balance code was found.

## 2. New payment architecture

```
                         DRIBEX
              ┌───────────┴───────────┐
              │                       │
         DISCOVERY                MONETIZATION
              │                       │
              ▼                       ▼
        Buyers/Sellers        Seller pays Dribex
              │                       │
              │                       ▼
              │                PaymentProvider
              │                  (manual | stripe | none)
              │                       │
              │                       ▼
              │                     Dribex
              ▼
     Buyer contacts seller
              ▼
   Transaction outside Dribex
```

**Explicit statement:** Dribex does not process, hold, escrow, or distribute payment for products sold by independent sellers.

### PaymentProvider abstraction

| Provider | Purpose |
|----------|---------|
| `manual` (default dev) | Immediate activation for local testing — records `dribex_service_payments` |
| `stripe` (optional) | Hosted Checkout for **Dribex service fees only** — no Connect/transfers |
| `none` | Billing disabled |

Configuration: `PAYMENT_PROVIDER`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`

**Moroccan entity note:** Stripe availability for a Morocco-incorporated company must be verified with Stripe and applicable regulators before production. The abstraction allows a Moroccan-authorized PSP to be added without rewriting business logic.

## 3. Removed marketplace-payment components

Already removed (migration 007):

- `orders`, `order_items`, `cart_items`, `buyer_addresses`, `coupons`, `wishlist_items`
- `orderstatus`, `paymentstatus` enums
- API routes `/cart`, `/checkout`, `/orders` (return 404 — tested)

Not present anywhere:

- Stripe Connect, destination charges, connected accounts, transfers, payouts
- `seller_balance`, `seller_wallet`, escrow, commission-from-buyer models

## 4. Retained Dribex-service payment components

| Component | Purpose |
|-----------|---------|
| `subscription_plans`, `subscriptions` | Premium / Seller Pro entitlements |
| `dribex_service_payments` | **Dribex revenue ledger** (subscription + advertising) |
| `advertising_packages`, `advertising_campaigns` | Sponsored listing / promoted product / featured seller |
| `payment_webhook_events` | Idempotent webhook processing |
| `POST /billing/checkout/subscription/{plan_code}` | Start subscription checkout |
| `POST /billing/checkout/advertising` | Start advertising checkout |
| `POST /billing/webhooks/{provider}` | Verified webhook ingestion |
| `POST /admin/users/{id}/premium` | Operational grant (no payment) |

## 5. Database changes

Migration **`014_discovery_payment_architecture`**:

- `dribex_service_payments` — platform revenue only
- `advertising_packages` — seeded packages
- `advertising_campaigns` — campaign lifecycle
- `payment_webhook_events` — replay protection

No seller payout or buyer purchase tables added.

## 6. API changes

| Endpoint | Change |
|----------|--------|
| `/billing/*` | **New** — checkout + webhooks + payment history |
| `/subscriptions/subscribe/{code}` | Delegates to platform billing in dev; blocked in prod without provider |
| `/cart`, `/checkout`, `/orders` | Still absent (404) |

## 7. Frontend changes

- Discovery notice on product and seller pages
- Off-platform payment disclaimer on accepted payment methods
- Premium screen clarifies fees are paid **to Dribex** for platform services
- Contact / Call / Message actions retained — no Buy/Checkout

## 8. Webhook changes

- Signature verification (Stripe: `stripe-signature` + `STRIPE_WEBHOOK_SECRET`)
- Idempotency via `payment_webhook_events`
- Server-side amount verification before activation
- Payment states: `pending`, `success`, `failed`, `cancelled`, `refunded`

## 9. Security changes

- No raw card storage — hosted checkout only when Stripe enabled
- Webhook signature required; forged requests rejected
- Frontend success URLs never activate entitlements without server confirmation
- Platform payments scoped to authenticated user / seller

## 10. Remaining legal / payment-provider dependencies

| Service | Data | Notes |
|---------|------|-------|
| Stripe (optional) | Billing customer metadata, payment references | Verify MA availability |
| SMTP | Email addresses | Transactional mail |
| Firebase (optional) | Auth identifiers | If enabled |
| Manual/admin billing | User IDs, plan codes | Operational |

Buyer↔seller commercial transactions occur **outside** Dribex — Dribex does not receive that payment data.

## 11. External services receiving personal/payment data

See also `legal/DATA_RESIDENCY_AUDIT.md` (if present). Payment data sent externally is limited to **Dribex service fees**, not product purchases.

## 12. Production-readiness risks

1. **Payment provider not configured in production** — self-serve premium/advertising returns 503 until `PAYMENT_PROVIDER=stripe` (or a Moroccan PSP adapter) is wired.
2. **Stripe + Morocco** — legal/technical eligibility must be confirmed before go-live.
3. **Advertising campaign expiry** — scheduled job to expire campaigns and reset `is_featured` not yet implemented.
4. **Refunds** — `refunded` status exists; automated refund flow not implemented.
5. **Legal copy** — mobile disclaimers are product UX, not legal advice; terms/privacy should be updated by counsel.

## Data-flow separation

### A. Buyer ↔ Seller commercial transaction

```
Buyer → discovers on Dribex → contacts seller → pays seller directly
```

Dribex revenue from this path: **MAD 0**

### B. Seller → Dribex service payment

```
Seller → selects premium/ad package → PaymentProvider → Dribex → service activated
```

Dribex revenue: **advertising fee / subscription fee** (platform service fee terminology)

Do not label advertising payments as marketplace transaction commissions.

## Commission model (prohibited vs allowed)

**Prohibited:** Buyer pays seller → Dribex takes commission → seller receives remainder

**Allowed:** Seller purchases Dribex advertising/subscription → Dribex keeps the fee
