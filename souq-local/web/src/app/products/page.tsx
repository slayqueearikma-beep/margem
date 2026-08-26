import { ProductCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchError, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export const metadata = buildPageMetadata({
  title: "Product listings",
  description: "Browse public product listings from Dribex sellers.",
  path: "/products",
});

type ProductsPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const params = await searchParams;
  const category = typeof params.category === "string" ? params.category : undefined;
  const city = typeof params.city === "string" ? params.city : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const outcome = await loadSearch({
    mode: "products",
    category,
    city,
    offset,
    limit,
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Products</h1>
        <p className="mt-2 text-[var(--muted)]">
          Public product listings from verified local sellers.
        </p>
      </div>

      {!outcome.ok ? (
        <ErrorState
          title="Products unavailable"
          description={describeFetchError(outcome)}
          retryHref="/products"
        />
      ) : outcome.data.products.length === 0 ? (
        <EmptyState
          title="No products found"
          description="Try another category or check back later."
          actionHref="/categories"
          actionLabel="Browse categories"
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {outcome.data.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
          <PaginationNav
            basePath="/products"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={outcome.data.total_products}
            params={{ category, city }}
          />
        </>
      )}
    </div>
  );
}
