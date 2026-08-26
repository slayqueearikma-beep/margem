import { SellerCard } from "@/components/listing-cards";
import { EmptyState } from "@/components/states";
import { fetchSellers } from "@/lib/marketplace-api";
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
  const city = typeof params.city === "string" ? params.city : undefined;
  const category = typeof params.category === "string" ? params.category : undefined;
  const q = typeof params.q === "string" ? params.q : undefined;

  const sellers = await fetchSellers({ city, category, q, limit: 48 }).catch(() => null);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Businesses</h1>
        <p className="mt-2 text-[var(--muted)]">
          Explore seller storefronts, ratings, and verification status.
        </p>
      </div>

      {!sellers ? (
        <EmptyState
          title="Directory unavailable"
          description="We couldn't load business profiles from the API."
          actionHref="/sellers"
          actionLabel="Retry"
        />
      ) : sellers.length === 0 ? (
        <EmptyState
          title="No businesses found"
          description="Try another city or category filter."
          actionHref="/cities"
          actionLabel="Browse cities"
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {sellers.map((seller) => (
            <SellerCard key={seller.id} seller={seller} />
          ))}
        </div>
      )}
    </div>
  );
}
