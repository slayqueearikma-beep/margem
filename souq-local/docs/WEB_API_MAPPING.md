# Dribex website → API mapping

Public Next.js storefront (`souq-local/web/`) consumes the existing Dribex REST API. No duplicate backend logic.

## Authentication

| Website area | Auth required | Notes |
| --- | --- | --- |
| Browse/search/listings | No | Public catalog and search endpoints |
| Seller dashboards, messaging, checkout | Yes (mobile app) | Not exposed on the public website |

## Feature mapping

| Website feature | Page(s) | API endpoint | Response fields used |
| --- | --- | --- | --- |
| Home discovery | `/` | `GET /search?mode=all&limit=8` | `products`, `services`, `sellers` |
| Categories index | `/categories` | `GET /categories` | `id`, `slug`, `name_en`, `name_fr`, `name_ar`, `icon` |
| Category listings | `/categories/[slug]` | `GET /search?mode=all&category={slug}` | products, services, sellers for category |
| Products index | `/products` | `GET /search?mode=products&offset&limit` | `products`, `total_products`, `has_more`, pagination |
| Product detail | `/products/[id]` | `GET /products/{id}` | `product.*`, `seller.*` |
| Services index | `/services` | `GET /search?mode=services&offset&limit` | `services`, `total_services`, `has_more` |
| Service detail | `/services/[id]` | `GET /services/{id}` | `service.*`, `seller.*` |
| Sellers directory | `/sellers` | `GET /search?mode=providers&offset&limit` | `sellers`, `total_sellers`, `has_more` |
| Seller storefront | `/sellers/[id]` | `GET /sellers/{id}`, `GET /sellers/{id}/reviews` | profile, products, services, reviews |
| Search | `/search` | `GET /search?q&mode&category&offset&limit` | all result types + totals |
| Cities index | `/cities` | `GET /geography/cities?country=MA` | city names, slugs, regions |
| City listings | `/cities/[slug]` | `GET /search?mode=all&city={name}` (Casablanca only) | products, services, sellers |
| Marketplaces | `/marketplaces/[slug]` | `GET /marketplaces`, `GET /marketplaces/{slug}/sellers` | marketplace metadata, seller list |

## Search modes

| Website `mode` | API `mode` |
| --- | --- |
| `all` | `all` |
| `products` | `products` |
| `services` | `services` |
| `sellers` | `providers` |

## Media URLs

Image fields (`image_url`, `cover_image_url`, `logo_image_url`) are resolved with `NEXT_PUBLIC_API_BASE_URL` for browser display.

## Launch cities

Only **Casablanca** is an active launch city on the website. Other cities show a “COMING SOON” ribbon and do not display invented listing counts. Backend search is scoped to the launch city (`LAUNCH_CITY`).

## Error handling

All pages use try/catch around API calls with loading, empty, retry, and `notFound()` states. Broken images fall back via `MediaImage`.
