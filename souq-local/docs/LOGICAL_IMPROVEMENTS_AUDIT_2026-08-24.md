# Dribex Logical Improvements Audit — 2026-08-24

Conservative improvements inside existing flows. No navigation, information architecture, or visual identity changes.

## Implemented

### 1. Marketplace slug validation before API calls
- **Wrong:** Stale/invalid marketplace slugs in storage caused 404s on `/sellers` and search.
- **Changed:** `validatedMarketplaceSlug()` guards slug against loaded marketplaces in home sellers, categories, and search.
- **Principle:** Market-scoped discovery reliability.
- **Flow preserved:** Same marketplace chips, search tab, and map entry points.

### 2. Search reacts to marketplace scope changes
- **Wrong:** Changing marketplace on home did not refresh search tab (IndexedStack).
- **Changed:** `ref.listen(buyerMarketplaceSlugProvider)` triggers search reload.
- **Principle:** Relevant search inside selected market.
- **Flow preserved:** Same search tab inside buyer shell.

### 3. Search filter / category state sync
- **Wrong:** “Clear filters” left `buyerCategorySlugProvider` set; badge ignored inherited category.
- **Changed:** Apply/clear updates shared category provider; active-filter badge includes it.
- **Principle:** Discovery clarity.
- **Flow preserved:** Same filter sheet UI.

### 4. Home feed decoupled from search category
- **Wrong:** Quick category on home filtered “Nearby businesses” silently after returning from search.
- **Changed:** Removed category from `buyerSellersProvider`; category applies only in search.
- **Principle:** Simple buyer home vs scoped search.
- **Flow preserved:** Category chips still open search with filter.

### 5. Market entry points set active scope
- **Wrong:** Popular market cards and “Open Market Map” did not persist/sync marketplace scope.
- **Changed:** Cards and map CTA set provider + storage; invalidate dependent providers.
- **Principle:** Market-first discovery.
- **Flow preserved:** Same cards, routes, and map screen.

### 6. Unified buyer city (Casablanca launch)
- **Wrong:** Home hardcoded city while map used saved city from storage — inconsistent labels/scope.
- **Changed:** Home uses shared `buyerCityProvider`; notifier resolves to launch city only.
- **Principle:** Moroccan launch focus, consistent discovery geography.
- **Flow preserved:** City row unchanged; no new city picker on home.

### 7. Distance uses GPS when available
- **Wrong:** Home “nearby” cards always used city center.
- **Changed:** Uses shared `buyerSearchLocationProvider` (GPS → city center fallback).
- **Principle:** Useful location information.
- **Flow preserved:** Same card layout.

### 8. Market-scoped empty states on home
- **Wrong:** Empty home always said “no businesses in city” even when a market was selected.
- **Changed:** Market-scoped copy when a marketplace chip is active.
- **Principle:** Market discovery clarity.
- **Flow preserved:** Same empty placement.

### 9. Map reloads when marketplace changes in-session
- **Wrong:** Map only reloaded in `didChangeDependencies`, not when slug changed on same route.
- **Changed:** Build watches slug/city and triggers reload.
- **Principle:** Market-oriented map.
- **Flow preserved:** Same map screen.

### 10. Custom market picker logic
- **Wrong:** Leftover custom text could override a selected listed market on save.
- **Changed:** Custom mode only when “More” selected; clears custom field when picking a listed market.
- **Principle:** Accurate market/location for sellers.
- **Flow preserved:** Same picker UI.

### 11. Seller registration category mapping
- **Wrong:** Display labels (`Food`, `Electronics`) never matched slug map → all sellers defaulted to food.
- **Changed:** `resolveSellerCategorySlug()` + marketplace-aware `categoryIdForSlug`.
- **Principle:** Relevant discovery categories.
- **Flow preserved:** Same registration wizard steps.

### 12. Optional product price → `offer` pricing type
- **Wrong:** UI allowed empty price but API required `price_mad` for default `fixed` type.
- **Changed:** Registration and product editor send `pricing_type: offer` when price empty.
- **Principle:** Simple seller listing flow.
- **Flow preserved:** Same forms.

### 13. Casablanca-only seller registration city
- **Wrong:** Sellers could register in other cities but backend discovery filters Casablanca only.
- **Changed:** Create payload uses launch city; city picker rejects non-Casablanca selection.
- **Principle:** Casablanca launch alignment.
- **Flow preserved:** Same step 2 layout.

### 14. Seller profile preserves city
- **Wrong:** Profile save overwrote city with hardcoded launch city.
- **Changed:** Sends existing `seller.city`.
- **Principle:** Data integrity.
- **Flow preserved:** Same profile screen.

### 15. Seller favorites show business name
- **Wrong:** Seller-only favorites returned empty `product_name` from API.
- **Changed:** Backend falls back to `business_name`; UI fallback on title.
- **Principle:** Simple buyer favorites UX.
- **Flow preserved:** Same wishlist screen.

### 16. Favorites sync across home hearts and wishlist
- **Wrong:** Removing favorite in wishlist did not refresh home heart state.
- **Changed:** Invalidate `buyerFavoriteSellerIdsProvider` on remove.
- **Principle:** Consistent buyer actions.
- **Flow preserved:** Same favorites routes.

### 17. Wishlist empty CTA opens search
- **Wrong:** “Browse products” returned home without opening discovery.
- **Changed:** Sets search tab index before navigating home.
- **Principle:** Discovery-first empty state.
- **Flow preserved:** Same button label.

### 18. Marketplace seller lists respect launch city
- **Wrong:** `/marketplaces/{slug}/sellers` did not filter by city unlike global seller list.
- **Changed:** Added `LAUNCH_CITY` filter to sellers and featured endpoints.
- **Principle:** Consistent Casablanca scope.
- **Flow preserved:** Same API routes.

### 19. Removed fabricated analytics delta
- **Wrong:** Dashboard showed `+18%` without real trend data.
- **Changed:** Delta label shows `—` until real analytics exist.
- **Principle:** Trust and credibility.
- **Flow preserved:** Same dashboard cards.

### 20. Prior session: API/frontend trust & premium fixes
- Seller video quota / featured products gated on seller Pro only (not buyer Plus).
- `phone_verified` no longer mapped from email verification.
- Report API calls require authentication.

## Intentionally not implemented (would change flow or scope)

- Saved searches mobile UI (new feature surface)
- Search pagination / geo sort UI (new controls)
- Split buyer vs seller premium in listing `is_premium` display (broader monetization change)
- Full seller profile category editor (new form section)
- Indoor market zone hierarchy on map
- Multi-city backend expansion beyond Casablanca

## Test results

Run after changes:
- Backend: `pytest tests/`
- Flutter: `flutter test`
