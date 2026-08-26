import { SellerCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState } from "@/components/states";
import { fetchSearch } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";

export const metadata = buildPageMetadata({
  title: "Business directory",
  description: "Browse public seller and business profiles on Dribex.",
  path: "/sellers",
});

type SellersPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function SellersPage({ searchParams }: SellersPageProps) {
  const params = await searchParams;
  const category = typeof params.category === "string" ? params.category : undefined;
  const q = typeof params.q === "string" ? params.q : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const results = await fetchSearch({
    mode: "providers",
    category,
    q,
    offset,
    limit,
  }).catch(() => null);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Businesses</h1>
        <p className="mt-2 text-[var(--muted)]">
          Explore seller storefronts, ratings, and verification status.
        </p>
      </div>

      {!results ? (
        <EmptyState
          title="Directory unavailable"
          description="We couldn't load business profiles from the API."
          actionHref="/sellers"
          actionLabel="Retry"
        />
      ) : results.sellers.length === 0 ? (
        <EmptyState
          title="No businesses found"
          description="Try another category filter or search the marketplace."
          actionHref="/search?mode=sellers"
          actionLabel="Search businesses"
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {results.sellers.map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
          <PaginationNav
            basePath="/sellers"
            offset={results.offset}
            limit={results.limit}
            hasMore={results.has_more}
            total={results.total_sellers}
            params={{ category, q }}
          />
        </>
      )}
    </div>
  );
}
