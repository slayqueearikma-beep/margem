# MarGem Stripe Billing Setup

Business subscription billing (VIP / Premium / Enterprise) via Stripe Checkout and Customer Portal.

## 1. Stripe Dashboard

1. Create a Stripe account and enable **Billing → Subscriptions**.
2. Create three **Products** with recurring **Prices** (monthly + yearly each):
   - **VIP** — e.g. 99 MAD/month, 990 MAD/year
   - **Premium** — e.g. 199 MAD/month, 1990 MAD/year
   - **Enterprise** — e.g. 499 MAD/month, 4990 MAD/year
3. Copy each **Price ID** (`price_...`).
4. Update `subscription_plans` in the database (or set via admin SQL):

```sql
UPDATE subscription_plans SET stripe_price_id_monthly = 'price_...', stripe_price_id_yearly = 'price_...' WHERE code = 'vip';
UPDATE subscription_plans SET stripe_price_id_monthly = 'price_...', stripe_price_id_yearly = 'price_...' WHERE code = 'premium';
UPDATE subscription_plans SET stripe_price_id_monthly = 'price_...', stripe_price_id_yearly = 'price_...' WHERE code = 'enterprise';
```

5. Configure **Customer Portal** (Settings → Billing → Customer portal):
   - Allow plan switching (upgrade/downgrade)
   - Allow cancellation
   - Show invoice history

6. Enable **email receipts** under Settings → Emails (Stripe sends these automatically).

## 2. API environment variables

```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SUCCESS_URL=https://margem.ma/premium/success
STRIPE_CANCEL_URL=https://margem.ma/premium/cancel
STRIPE_PORTAL_RETURN_URL=https://margem.ma/premium
STRIPE_TRIAL_ENABLED=true
```

## 3. Webhook endpoint

Register in Stripe Dashboard → Developers → Webhooks:

```
https://api.margem.ma/billing/webhooks/stripe
```

**Events to subscribe:**
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`

Local testing:

```bash
stripe listen --forward-to localhost:8000/billing/webhooks/stripe
```

## 4. API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/billing/config` | Public billing capabilities |
| POST | `/billing/checkout` | Create Stripe Checkout session (seller auth) |
| POST | `/billing/portal` | Customer Portal URL |
| POST | `/billing/change-plan` | Prorated upgrade/downgrade |
| POST | `/billing/sync` | Refresh subscription from Stripe (post-checkout) |
| POST | `/billing/cancel` | Cancel at period end |
| POST | `/billing/webhooks/stripe` | Webhook receiver |

## 5. Reconciliation cron

```bash
python scripts/stripe_reconcile.py
```

Also runs on API startup when `STRIPE_SECRET_KEY` is set.

### Sync Stripe Price IDs from env (deploy)

```bash
# Set STRIPE_VIP_PRICE_MONTHLY, STRIPE_VIP_PRICE_YEARLY, etc. then:
python scripts/sync_stripe_prices.py
```

## 6. Mobile

- **Upgrade** → `POST /billing/checkout` → opens Stripe Checkout in browser
- **After payment** → success URL opens `/premium/success?session_id=...` → `POST /billing/sync` activates immediately
- **Manage billing** → `POST /billing/portal` → Stripe Customer Portal
- Dev fallback: `POST /subscriptions/subscribe/{code}` when Stripe is not configured

For native deep links, set:

```env
STRIPE_SUCCESS_URL=https://margem.ma/premium/success
STRIPE_CANCEL_URL=https://margem.ma/premium/cancel
STRIPE_PORTAL_RETURN_URL=https://margem.ma/premium
```

(Android/iOS deep links are registered for `/premium/success` and `/premium/cancel`.)

## 7. Admin

- `POST /admin/users/{id}/premium` — manual grant (override)
- `DELETE /admin/users/{id}/premium` — revoke (+ cancels Stripe sub if present)
- `POST /admin/users/{id}/premium/sync-stripe` — force reconciliation
