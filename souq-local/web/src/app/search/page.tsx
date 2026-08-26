import { Suspense } from "react";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { SearchBar } from "@/components/search-bar";
import { EmptyState } from "@/components/states";
import { ApiError } from "@/lib/api";
import { fetchSearch, fetchServices } from "@/lib/marketplace-api";
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

  let productResults = null;
  let serviceResults = null;
  let errorMessage: string | null = null;

  try {
    if (mode === "services") {
      serviceResults = await fetchServices({ q, category, city, offset, limit: 24 });
    } else {
      const requests: [Promise<Awaited<ReturnType<typeof fetchSearch>>>, Promise<Awaited<ReturnType<typeof fetchServices>>> | null] = [
        fetchSearch({
          q,
          mode: mode === "sellers" ? "sellers" : mode,
          category,
          city,
          offset,
          limit: 24,
        }),
        mode === "all"
          ? fetchServices({ q, category, city, offset, limit: 12 })
          : null,
      ];
      productResults = await requests[0];
      if (requests[1]) {
        serviceResults = await requests[1];
      }
    }
  } catch (error) {
    errorMessage = error instanceof ApiError ? error.message : "Search failed";
  }

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

      {!errorMessage && mode === "services" && serviceResults ? (
        serviceResults.items.length === 0 ? (
          <EmptyState
            title="No services found"
            description="Try another keyword or browse businesses offering services."
            actionHref="/sellers"
            actionLabel="Browse businesses"
          />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {serviceResults.items.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        )
      ) : null}

      {!errorMessage && serviceResults && mode === "all" && serviceResults.items.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Services</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {serviceResults.items.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        </section>
      ) : null}

      {!errorMessage && productResults && mode !== "services" ? (
        <>
          {(mode === "all" || mode === "products") && productResults.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Products</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {productResults.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {(mode === "all" || mode === "sellers") && productResults.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Businesses</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {productResults.sellers.map((seller) => (
                  <SellerCard key={seller.id} seller={seller} />
                ))}
              </div>
            </section>
          ) : null}

          {productResults.products.length === 0 &&
          productResults.sellers.length === 0 &&
          (!serviceResults || serviceResults.items.length === 0) ? (
            <EmptyState
              title="No results"
              description="Try a different search term or remove filters."
              actionHref="/categories"
              actionLabel="Browse categories"
            />
          ) : null}
        </>
      ) : null}
    </div>
  );
}
