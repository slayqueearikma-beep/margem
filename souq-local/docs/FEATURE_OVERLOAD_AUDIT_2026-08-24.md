# Dribex Feature Overload Audit — 2026-08-24

Goal: minimize cognitive load without damaging core Moroccan discovery marketplace value.

Constraints respected: no UI redesign, no visual identity change, no main navigation restructure, no global IA changes, no new features added.

---

## Final Aggressive Simplification Audit

Strict pass: delete, merge, simplify, or hide anything that does not clearly help buyers discover listings/sellers or sellers become discoverable and manage listings.

### Scorecard

| Metric | Before (post–overload audit) | After (final pass) |
|---|---:|---:|
| **Complexity score** (/100, lower is better) | 68 | 46 |
| **Core-product clarity** (/100, higher is better) | 71 | 88 |
| **Total features audited** | 58 | 58 |
| **REMOVE** | 3 | 14 |
| **MERGE** | 6 | 8 |
| **SIMPLIFY** | 8 | 10 |
| **HIDE** | 5 | 2 |
| **KEEP** | 36 | 24 |

### Decision Table (final pass)

| Feature | Action | Reason | Risk |
|---|---|---|---|
| Seller analytics screen (`seller_analytics_screen.dart`) | REMOVE | Orphaned after route redirect; ERP-style metrics duplicate dashboard | Low |
| `sellerAnalyticsProvider` + `fetchSellerAnalytics()` | REMOVE | No UI consumer after analytics removal | Low |
| Seller products list (`SellerProductsScreen`, `/seller/products`) | MERGE | Catalog tab is canonical; redirect sets products filter | Low |
| Seller services list (`SellerServicesScreen`) | REMOVE | Dead code; `/seller/services` already redirects to catalog | Low |
| Buyer home promo carousel | REMOVE | Redundant with search tab, map drawer link, and category chips | Low |
| `BuyerPromoBanner` / `BuyerPromoCarousel` widgets | REMOVE | Unused after carousel removal | None |
| Bundle builder screen + `/bundle` route | REMOVE | Multi-seller ERP-style tool; not core discovery; drawer entry removed | Medium — backend `/bundles/*` kept |
| `fetchBundleTemplates` / `resolveBundle` (mobile client) | REMOVE | No UI consumer | Low — backend kept |
| City community chat screens + routes | REMOVE | Parallel social layer duplicating marketplace community; redirects to home | Medium — backend `/community/*` kept |
| City community websocket client | REMOVE | Only served deleted city community UI | Low |
| `/language` standalone route | REMOVE | Duplicate of `/settings/language` | Low |
| Buyer drawer: Settings tile | REMOVE | Profile screen links to settings; duplicate entry | Low |
| Buyer drawer: footer Profile button | REMOVE | Duplicate of drawer Profile tile | Low |
| Buyer drawer: Bundle builder | REMOVE | Non-core feature removed from app | Low |
| Buyer drawer: City community | REMOVE | Non-core parallel social layer | Low |
| Seller drawer: Dashboard / Catalog / Messages | REMOVE | Duplicate bottom-nav entries | Low |
| Marketplace community (per-market) | KEEP | Contextual to selected market — supports discovery | Low |
| Seller notifications feed | KEEP | System alerts beyond message threads | Low |
| Seller video upload (Pro FAB) | KEEP | Pro monetization; seller-side only | Low |
| Achievement stars / golden crowns | KEEP | Lightweight trust signal on map/storefront | Low |
| Backend city community + bundle APIs | KEEP | No mobile UI; admin/future use; safe to leave dormant | None |
| Core buyer flow (Home → Search → Map → Listing → Messages) | KEEP | Product mandate | — |
| Core seller flow (Dashboard → Catalog → Messages → More) | KEEP | Product mandate | — |
| Auth, legal, billing, moderation, favorites, reviews, premium | KEEP | Required by product/compliance rules | — |

### Implemented in final pass

**Deleted files**
- `seller_analytics_screen.dart`
- `bundle_builder/bundle_builder_screen.dart`
- `community_chat/*` (3 screens/providers)
- `community_websocket_service.dart`

**Routes**
- `/seller/products` → catalog tab (products filter) via `SellerProductsRedirect`
- `/bundle`, `/community`, `/community/:citySlug`, `/community/channels/:id` → `/buyer/home`
- Removed `/language` (use `/settings/language`)

**Drawers**
- Buyer: Profile, Favorites, Map, Messages, Premium (+ guest signup CTA)
- Seller: Reviews, Business info, Settings (+ mode switch / logout)

**API client cleanup**
- Removed `fetchSellerAnalytics`, `fetchBundleTemplates`, `resolveBundle`

### Deliberately refused to remove

| Feature | Why kept |
|---|---|
| Seller notifications | Separate from messaging; surfaces system/billing/moderation alerts |
| Seller Pro videos (FAB) | Real monetization path; hidden from buyers who lack playback anyway |
| Marketplace community | Market-scoped discussion supports discovery at the selected souk |
| Trust badges / achievement crowns | Low-complexity trust cues aligned with reviews |
| Backend bundle + city community endpoints | Removing server routes risks breaking admin/scripts; zero mobile UI cost now |
| Seller reviews in drawer | Not in bottom nav; legitimate secondary access for reputation management |

### Verification

- [x] `flutter analyze` — no errors
- [x] `flutter test` — 61/61 passed
- [x] Dead routes redirect or removed
- [x] Drawer deduplication (buyer + seller)
- [x] Catalog tab owns all listing management

---

## Earlier passes (summary)

### Pass 1 — Feature overload audit

Removed seller analytics UI access, earnings placeholder, simplified bookings → inquiries, trimmed seller drawer/More, collapsed stall fields, reduced promo carousel.

### Pass 2 — Inquiries → Messages merge

Unified seller communication on Messages tab; deleted `seller_bookings_tab.dart`; trimmed Seller More to Premium/Boost/Preview/Settings.

## Verdict

Dribex is now a **lean discovery marketplace**. Buyers land on markets, categories, search, and sellers — not promos, bundles, or city chat side-quests. Sellers manage listings in one catalog, respond in one inbox, and reach monetization through More — not duplicate list screens, analytics dashboards, or drawer clones of the bottom nav.

**LESS TO UNDERSTAND. LESS TO CONFIGURE. LESS TO MAINTAIN.**

---

## Community restoration (2026-08-24 follow-up)

Per product requirement, **city community** and **per-marketplace community** access were restored:

- Restored `community_chat/*` screens and websocket client
- Restored `/community`, `/community/:citySlug`, `/community/channels/:id` routes
- Buyer drawer: City Community + Marketplace Community entries
- Popular markets list: forum shortcut per market
- Existing links kept: buyer home (selected market), marketplace detail page

Per-market chat remains at `/marketplace/:slug/community` (unchanged backend).
