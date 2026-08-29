import { SellerCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchError, loadSearch } from "@/lib/marketplace-fetch";
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

  const outcome = await loadSearch({
    mode: "providers",
    category,
    q,
    offset,
    limit,
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Businesses</h1>
        <p className="mt-2 text-[var(--muted)]">
          Explore seller storefronts, ratings, and verification status.
        </p>
      </div>

      {!outcome.ok ? (
        <ErrorState
          title="Directory unavailable"
          description={describeFetchError(outcome)}
          retryHref="/sellers"
        />
      ) : outcome.data.sellers.length === 0 ? (
        <EmptyState
          title="No businesses found"
          description="Try another category filter or search the marketplace."
          actionHref="/search?mode=sellers"
          actionLabel="Search businesses"
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {outcome.data.sellers.map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
          <PaginationNav
            basePath="/sellers"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={outcome.data.total_sellers}
            params={{ category, q }}
          />
        </>
      )}
    </div>
  );
}
