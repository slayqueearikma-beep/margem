# NAPS Payment Migration — Dribex

## Business model (unchanged)

Dribex is a **discovery and advertising platform**. Dribex does **not** process, hold, escrow, split, or distribute payments for products sold by independent sellers.

**NAPS** (NAPS SA, Morocco — https://naps.ma/paiements-en-ligne/) is used **only** to process payments made **to Dribex** for Dribex-owned services:

- Premium subscriptions
- Sponsored listings
- Promoted products
- Featured seller placement
- Advertising packages

Transactions between buyers and independent sellers occur **outside Dribex**.

## Stripe removal

All active Stripe runtime dependencies have been removed:

- Stripe Python SDK
- Stripe Checkout integration
- Stripe webhook handlers
- Stripe environment variables

Historical records with `provider=stripe` may remain in the database for audit purposes. These records are **read-only** and never invoke Stripe at runtime.

## NAPS integration boundary

Production uses `PAYMENT_PROVIDER=naps`.

The integration is implemented behind:

- `app/services/payment_provider.py` — provider abstraction
- `app/services/naps_payment_provider.py` — NAPS adapter
- `app/services/naps_client.py` — HTTP boundary (config-driven)

### Required merchant documentation

Official NAPS ePay API documentation is provided by NAPS SA after merchant affiliation. The following must be obtained from NAPS before production go-live:

| Item | Status |
|------|--------|
| Merchant affiliation approval | Required from NAPS |
| Sandbox credentials | Required from NAPS |
| Production credentials | Required from NAPS |
| Payment initiation endpoint URL | Configure `NAPS_EPAY_PAYMENT_INIT_URL` |
| Payment status query endpoint | Configure `NAPS_EPAY_PAYMENT_STATUS_URL` |
| Request authentication / signing specification | Configure signing + headers |
| Webhook payload schema | Configure field mapping env vars |
| Webhook signature algorithm | Configure `NAPS_WEBHOOK_SECRET` + header |
| Recurring billing API (if enabled for merchant) | Not yet wired — requires docs |
| Refund API specification | Partial — `payment_refunds` table ready |
| Subscription cancellation API | Partial — local cancel only until NAPS docs |

**Do not deploy to production until NAPS merchant integration guide values are configured.**

## Environment variables

```env
PAYMENT_PROVIDER=naps          # production
PAYMENT_CURRENCY=mad
NAPS_ENVIRONMENT=sandbox|production
NAPS_MERCHANT_ID=
NAPS_API_KEY=
NAPS_SECRET_KEY=
NAPS_WEBHOOK_SECRET=
NAPS_EPAY_PAYMENT_INIT_URL=
NAPS_EPAY_PAYMENT_STATUS_URL=
NAPS_WEBHOOK_SIGNATURE_HEADER=X-NAPS-Signature
```

Field mapping variables allow aligning with the official NAPS JSON schema without code changes.

## Development

Local development uses `PAYMENT_PROVIDER=manual` with `ALLOW_MANUAL_BILLING=true`. Manual billing is **blocked in production**.

## Data sent to NAPS

Minimized to payment processing needs:

- Order/payment ID (internal UUID)
- Amount and currency (MAD, server-side authoritative)
- Success/cancel redirect URLs
- Service type/code metadata

Do **not** send private messages, unrelated profile data, or unnecessary product content.

## Third-party inventory

Add NAPS SA to the data-processing registry as a payment processor for platform service fees.

## Legal disclaimer

This document describes **technical architecture only**. NAPS merchant approval, Moroccan payment regulation, taxation, consumer law, and CNDP/data-protection obligations require separate legal review.
