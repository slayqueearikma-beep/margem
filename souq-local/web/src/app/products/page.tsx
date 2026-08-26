import { ProductCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState } from "@/components/states";
import { fetchSearch } from "@/lib/marketplace-api";
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

  const results = await fetchSearch({
    mode: "products",
    category,
    city,
    offset,
    limit,
  }).catch(() => null);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Products</h1>
        <p className="mt-2 text-[var(--muted)]">
          Public product listings from verified local sellers.
        </p>
      </div>

      {!results ? (
        <EmptyState
          title="Products unavailable"
          description="We couldn't load product listings from the API."
          actionHref="/products"
          actionLabel="Retry"
        />
      ) : results.products.length === 0 ? (
        <EmptyState
          title="No products found"
          description="Try another category or check back later."
          actionHref="/categories"
          actionLabel="Browse categories"
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {results.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
          <PaginationNav
            basePath="/products"
            offset={results.offset}
            limit={results.limit}
            hasMore={results.has_more}
            total={results.total_products}
            params={{ category, city }}
          />
        </>
      )}
    </div>
  );
}
