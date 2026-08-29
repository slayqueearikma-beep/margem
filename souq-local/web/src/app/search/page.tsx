import { Suspense } from "react";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { SearchBar } from "@/components/search-bar";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchError, loadActiveAdvertisements, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export const metadata = buildPageMetadata({
  title: "Search the marketplace",
  description: "Search Dribex products, services, and local businesses.",
  path: "/search",
});

type SearchPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const params = await searchParams;
  const q = typeof params.q === "string" ? params.q : "";
  const mode = typeof params.mode === "string" ? params.mode : "all";
  const category = typeof params.category === "string" ? params.category : undefined;
  const city = typeof params.city === "string" ? params.city : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const searchMode =
    mode === "sellers" ? "providers" : mode === "products" || mode === "services" ? mode : "all";

  const outcome = await loadSearch({
    q,
    mode: searchMode,
    category,
    city,
    offset,
    limit,
  });
  const ads = await loadActiveAdvertisements("search_results", { city, categorySlug: category });

  const filterParams = {
    q: q || undefined,
    mode: mode !== "all" ? mode : undefined,
    category,
    city,
  };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Search</h1>
        <p className="mt-2 text-[var(--muted)]">
          Find products, services, and businesses across the public marketplace.
        </p>
      </div>

      <Suspense fallback={null}>
        <SearchBar defaultQuery={q} defaultMode={mode} />
      </Suspense>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="search_results" /> : null}

      {!outcome.ok ? (
        <ErrorState
          title="Search unavailable"
          description={describeFetchError(outcome)}
          retryHref="/search"
        />
      ) : (
        <>
          {(mode === "all" || mode === "products") && outcome.data.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Products</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {outcome.data.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {(mode === "all" || mode === "services") && outcome.data.services.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Services</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {outcome.data.services.map((service) => (
                  <ServiceCard key={service.id} service={service} />
                ))}
              </div>
            </section>
          ) : null}

          {(mode === "all" || mode === "sellers") && outcome.data.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Businesses</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {outcome.data.sellers.map((seller) => (
                  <SellerCard key={seller.id} seller={seller} />
                ))}
              </div>
            </section>
          ) : null}

          {outcome.data.products.length === 0 &&
          outcome.data.services.length === 0 &&
          outcome.data.sellers.length === 0 ? (
            <EmptyState
              title="No results"
              description="Try a different search term or remove filters."
              actionHref="/categories"
              actionLabel="Browse categories"
            />
          ) : null}

          <PaginationNav
            basePath="/search"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={
              mode === "products"
                ? outcome.data.total_products
                : mode === "services"
                  ? outcome.data.total_services
                  : mode === "sellers"
                    ? outcome.data.total_sellers
                    : undefined
            }
            params={filterParams}
          />
        </>
      )}
    </div>
  );
}
