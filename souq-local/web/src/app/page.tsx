import Link from "next/link";
import { Suspense } from "react";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { SearchBar } from "@/components/search-bar";
import { EmptyState, LoadingGrid } from "@/components/states";
import { BRAND } from "@/lib/config";
import { fetchCategories, fetchMarketplaces, fetchSearch } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";
import { categoryLabel } from "@/lib/format";

export const metadata = buildPageMetadata({
  title: `${BRAND.name} — Discover local marketplace listings`,
  description:
    "Browse products, services, and verified local businesses on Dribex. Search Casablanca marketplace listings without signing in.",
  path: "/",
});

export default async function HomePage() {
  const [search, categories, marketplaces] = await Promise.all([
    fetchSearch({ mode: "all", limit: 8 }).catch(() => null),
    fetchCategories().catch(() => []),
    fetchMarketplaces().catch(() => null),
  ]);

  return (
    <div className="space-y-12">
      <section className="overflow-hidden rounded-3xl bg-gradient-to-br from-[var(--cream)] via-white to-[var(--primary-muted)] px-6 py-10 sm:px-10">
        <div className="max-w-2xl">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-[var(--primary)]">
            Public marketplace
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">
            Discover trusted local sellers on {BRAND.name}
          </h1>
          <p className="mt-4 text-base text-[var(--muted)]">
            Browse products, services, and business profiles from Morocco&apos;s marketplace
            community. No login required to explore.
          </p>
        </div>
        <div className="mt-8">
          <Suspense fallback={<div className="h-16 animate-pulse rounded-2xl bg-white/70" />}>
            <SearchBar />
          </Suspense>
        </div>
      </section>

      {categories.length > 0 ? (
        <section>
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold">Shop by category</h2>
              <p className="text-sm text-[var(--muted)]">Popular ways to start exploring</p>
            </div>
            <Link href="/categories" className="text-sm font-semibold text-[var(--primary)]">
              View all
            </Link>
          </div>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {categories.slice(0, 8).map((category) => (
              <Link
                key={category.id}
                href={`/categories/${category.slug}`}
                className="rounded-2xl border border-[var(--border)] bg-white px-4 py-5 transition hover:border-[var(--primary)] hover:shadow-sm"
              >
                <p className="font-semibold">{categoryLabel(category)}</p>
                <p className="mt-1 text-xs uppercase tracking-wide text-[var(--muted)]">
                  {category.slug}
                </p>
              </Link>
            ))}
          </div>
        </section>
      ) : null}

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">Featured products</h2>
            <p className="text-sm text-[var(--muted)]">Fresh listings from local sellers</p>
          </div>
          <Link href="/products" className="text-sm font-semibold text-[var(--primary)]">
            See all products
          </Link>
        </div>
        {!search ? (
          <EmptyState
            title="Marketplace unavailable"
            description="We couldn't reach the Dribex API. Start the backend and refresh this page."
            actionHref="/"
            actionLabel="Refresh"
          />
        ) : search.products.length === 0 ? (
          <EmptyState
            title="No products yet"
            description="Check back soon as sellers publish new inventory."
            actionHref="/sellers"
            actionLabel="Browse businesses"
          />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">Featured services</h2>
            <p className="text-sm text-[var(--muted)]">Local services from verified businesses</p>
          </div>
          <Link href="/services" className="text-sm font-semibold text-[var(--primary)]">
            See all services
          </Link>
        </div>
        {search && search.services.length > 0 ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.services.slice(0, 4).map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        ) : search ? (
          <EmptyState
            title="No services yet"
            description="Check back soon as businesses publish new offerings."
            actionHref="/sellers"
            actionLabel="Browse businesses"
          />
        ) : null}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">Top businesses</h2>
            <p className="text-sm text-[var(--muted)]">Verified and highly rated sellers</p>
          </div>
          <Link href="/sellers" className="text-sm font-semibold text-[var(--primary)]">
            View directory
          </Link>
        </div>
        {search && search.sellers.length > 0 ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {search.sellers.slice(0, 6).map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
        ) : (
          <LoadingGrid count={3} />
        )}
      </section>

      {marketplaces && marketplaces.length > 0 ? (
        <section>
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold">Markets</h2>
              <p className="text-sm text-[var(--muted)]">Explore sellers by market location</p>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {marketplaces.slice(0, 6).map((marketplace) => (
              <Link
                key={marketplace.id}
                href={`/marketplaces/${marketplace.slug}`}
                className="rounded-2xl border border-[var(--border)] bg-white p-5 transition hover:shadow-sm"
              >
                <h3 className="font-semibold">{marketplace.name}</h3>
                <p className="mt-2 line-clamp-2 text-sm text-[var(--muted)]">
                  {marketplace.description}
                </p>
                <p className="mt-3 text-xs text-[var(--muted)]">
                  {marketplace.seller_count ?? 0} sellers · {marketplace.city}
                </p>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
