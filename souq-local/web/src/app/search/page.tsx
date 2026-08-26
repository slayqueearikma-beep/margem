import { Suspense } from "react";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { SearchBar } from "@/components/search-bar";
import { EmptyState } from "@/components/states";
import { ApiError } from "@/lib/api";
import { fetchSearch } from "@/lib/marketplace-api";
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

  let results = null;
  let errorMessage: string | null = null;

  try {
    results = await fetchSearch({
      q,
      mode: searchMode,
      category,
      city,
      offset,
      limit,
    });
  } catch (error) {
    errorMessage = error instanceof ApiError ? error.message : "Search failed";
  }

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

      {errorMessage ? (
        <EmptyState
          title="Search unavailable"
          description={errorMessage}
          actionHref="/search"
          actionLabel="Retry"
        />
      ) : null}

      {!errorMessage && results ? (
        <>
          {(mode === "all" || mode === "products") && results.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Products</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {results.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {(mode === "all" || mode === "services") && results.services.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Services</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {results.services.map((service) => (
                  <ServiceCard key={service.id} service={service} />
                ))}
              </div>
            </section>
          ) : null}

          {(mode === "all" || mode === "sellers") && results.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Businesses</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {results.sellers.map((seller) => (
                  <SellerCard key={seller.id} seller={seller} />
                ))}
              </div>
            </section>
          ) : null}

          {results.products.length === 0 &&
          results.services.length === 0 &&
          results.sellers.length === 0 ? (
            <EmptyState
              title="No results"
              description="Try a different search term or remove filters."
              actionHref="/categories"
              actionLabel="Browse categories"
            />
          ) : null}

          <PaginationNav
            basePath="/search"
            offset={results.offset}
            limit={results.limit}
            hasMore={results.has_more}
            total={
              mode === "products"
                ? results.total_products
                : mode === "services"
                  ? results.total_services
                  : mode === "sellers"
                    ? results.total_sellers
                    : undefined
            }
            params={filterParams}
          />
        </>
      ) : null}
    </div>
  );
}
