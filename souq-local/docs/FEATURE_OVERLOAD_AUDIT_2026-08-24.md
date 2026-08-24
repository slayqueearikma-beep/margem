# Dribex Feature Overload Audit — 2026-08-24

Goal: minimize cognitive load without damaging core Moroccan discovery marketplace value.

Constraints respected: no UI redesign, no visual identity change, no main navigation restructure, no global IA changes, no new features added.

## Summary

| Metric | Count |
|---|---|
| **Total features audited** | 52 |
| **KEEP** | 34 |
| **SIMPLIFY** | 8 |
| **MERGE** | 4 |
| **HIDE / MOVE TO SECONDARY** | 5 |
| **REMOVE (from primary surfaces)** | 1 |

*Note: “Remove” here means removing prominent access or placeholder shells—not deleting core backend capability or legal/security flows.*

## Decision Table

| Feature | Decision | Reason | Impact |
|---|---|---|---|
| Buyer home discovery feed | KEEP | Core purpose: find products, sellers, markets | Low |
| Marketplace chips & popular markets | KEEP | Casablanca market-first discovery | Low |
| Search (products / services / providers) | KEEP | Core discovery loop | Low |
| Map with market pins & zones | KEEP | Location discovery for physical shops | Low |
| Seller storefront pages | KEEP | Core buyer→seller path | Low |
| Product / service detail pages | KEEP | Listing discovery | Low |
| Favorites (products & sellers) | KEEP | Saved discoveries — genuinely useful | Low |
| Follow sellers | KEEP | Lightweight discovery retention | Low |
| Reviews & trust indicators | KEEP | Credibility without ERP complexity | Low |
| Direct messages (buyer↔seller) | KEEP | Core contact channel | Low |
| Seller registration & become-seller | KEEP | Seller discoverability onboarding | Low |
| Seller catalog (products & services) | KEEP | Listing management essential | Low |
| Seller business profile | KEEP | Discoverability + trust | Low |
| Market stall location fields | SIMPLIFY | Useful for indoor markets but collapsed behind expansion | Medium |
| Seller category editor | KEEP | Helps buyers find relevant sellers | Low |
| Authentication & email verification | KEEP | Security / account integrity | Low |
| Legal acceptance & privacy hub | KEEP | Compliance (Law 09-08, contracts) | Low |
| Account deletion & data export | KEEP | Legal requirement | Low |
| Premium / Dribex Plus (buyer) | KEEP | Saved searches & buyer value | Low |
| Seller Pro subscription | KEEP | Video quota, visibility — real monetization | Low |
| Billing settings | KEEP | Subscription self-service | Low |
| Saved searches (premium) | KEEP | Buyer discovery utility | Low |
| Marketplace detail pages | KEEP | Market-first architecture | Low |
| Marketplace community (per market) | KEEP | Contextual to selected market | Low |
| Report / block users | KEEP | Trust & safety | Low |
| Warning zones on map | KEEP | Buyer safety signal | Low |
| Share links / QR resolution | KEEP | Seller visibility helper | Low |
| Onboarding welcome & account type | KEEP | Clear buyer vs seller intent | Low |
| Guest browsing | KEEP | Low-friction discovery entry | Low |
| Settings (language, theme, privacy) | KEEP | Essential account management | Low |
| Seller notifications feed | KEEP | Seller response loop | Low |
| Seller video upload (Pro) | HIDE | Useful for Pro sellers but stays in FAB only | Low |
| Seller boost / advertising checkout | HIDE | Monetization valid but moved to More tab only | Medium |
| Bundle builder | HIDE | Secondary multi-seller tool — drawer only, removed home promo | Medium |
| City community chat | HIDE | Parallel to marketplace community — removed home carousel promo; drawer retained | Medium |
| Buyer drawer (profile, favorites, map) | KEEP | Secondary navigation without cluttering home | Low |
| Buyer profile hub | SIMPLIFY | Removed duplicate dark-mode toggle (settings owns theme) | Low |
| Account settings | MERGE | Removed change-password tile that only routed back to profile | Low |
| Seller analytics screen | REMOVE | ERP-like metrics duplicated dashboard; route redirects to dashboard | High |
| Seller earnings placeholder | REMOVE | “Coming soon” added noise without value | Medium |
| Bookings tab (fake completed/cancelled) | SIMPLIFY | Renamed to Inquiries; removed empty booking segments | Medium |
| Seller dashboard metrics | SIMPLIFY | Removed sparkline hero + duplicate message tile + earnings tile | Medium |
| Seller drawer | SIMPLIFY | Removed analytics, boost, earnings, duplicate gallery link | Medium |
| Seller More tab | MERGE | Removed analytics & duplicate product management; boost moved here | Medium |
| Seller product list (`/seller/products`) | MERGE | Catalog tab is primary; removed duplicate More/drawer “Gallery” entry | Low |
| Achievement stars / golden crowns | KEEP | Lightweight trust gamification on map/storefront | Low |
| City-based community (`/community`) | KEEP | Secondary social layer — de-emphasized not deleted | Low |
| Admin / moderation APIs | KEEP | Required for operations — not exposed in mobile primary UI | Low |
| DSAR privacy requests | KEEP | Legal compliance | Low |
| MFA / session management | KEEP | Security | Low |
| Contact event tracking | KEEP | Backend analytics for trust; no new buyer UI added | Low |
| `/seller/analytics` deep links | MERGE | Redirects to dashboard — no broken bookmarks | Low |
| Promo carousel (search + map) | SIMPLIFY | Reduced from 3 slides to 2; removed community slide | Low |
| Password change (buyer profile) | KEEP | Single location after removing settings duplicate | Low |
| Seller settings (theme, billing, password) | KEEP | Consolidated account security | Low |
| Map zone hierarchy panel | KEEP | Supports indoor market discovery without new IA | Low |
| Geo-sort in search | KEEP | Discovery relevance | Low |

## Implemented Changes (this PR)

### Removed from primary surfaces
- Seller **Analytics** screen access (drawer, More tab); `/seller/analytics` → `/seller/dashboard`
- **Earnings** placeholder (drawer + dashboard tile)
- Fake **bookings** completed/cancelled filters

### Simplified
- Seller dashboard: 3 metric tiles (views, inquiries, reviews); no sparkline analytics card
- Bookings tab → **Inquiries** tab (bottom nav label)
- Seller profile: stall/zone fields collapsed in `ExpansionTile`
- Buyer home promo carousel: 2 slides (search, map)
- Buyer profile: dark mode toggle removed (settings retains it)

### Merged / deduplicated
- Removed duplicate **Product Management** from More tab (Catalog tab owns listings)
- Removed duplicate **Gallery** drawer link to products list
- Removed account settings **change password** tile that only opened profile

### Moved to secondary
- **Bundle builder**: removed home card; still in buyer drawer
- **City community**: removed home carousel slide; still in drawer
- **Seller boost**: removed from drawer; available under More → Boost

## Dependency Checks

| Change | Frontend | Backend | DB | Risk |
|---|---|---|---|---|
| Analytics UI removal | Route redirect only | `/seller/analytics` API unchanged | No change | Low — dashboard still uses `/sellers/me/dashboard` stats |
| Earnings placeholder | UI only | No endpoint existed | No change | None |
| Bookings simplification | UI only | Inquiries use existing message/inquiry counts | No change | None |
| Bundle/community home removal | Navigation only | Endpoints unchanged | No change | None |
| Profile expansion tile | UI only | Same PATCH payload | No change | None |

## Test Checklist (manual / automated)

- [x] Flutter analyze on changed seller/buyer modules
- [x] Subscription provider unit tests
- [x] Backend premium tests (prior branch baseline)
- [ ] Full Flutter suite (recommended before merge)
- [ ] Smoke: first launch → guest home
- [ ] Smoke: buyer search + map + favorites
- [ ] Smoke: seller dashboard → catalog → add listing
- [ ] Smoke: seller More → boost + premium
- [ ] Smoke: `/seller/analytics` redirect

## Verdict

Dribex remains a **focused Moroccan discovery marketplace**. Buyers land on markets, search, and map—not bundle/community promos. Sellers see **listings, inquiries, and reviews** first—not analytics dashboards or placeholder earnings. Secondary tools (boost, bundles, city chat) remain reachable without competing with discovery.
