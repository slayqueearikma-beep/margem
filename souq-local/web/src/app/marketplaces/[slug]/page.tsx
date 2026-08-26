import Link from "next/link";
import { notFound } from "next/navigation";
import { SellerCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { ApiError } from "@/lib/api";
import {
  describeFetchError,
  loadMarketplace,
  loadMarketplaceSellers,
} from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type MarketplaceDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const outcome = await loadMarketplace(slug);
  if (!outcome.ok) {
    return buildPageMetadata({
      title: "Market not found",
      description: "This marketplace is unavailable.",
      path: `/marketplaces/${slug}`,
    });
  }
  return buildPageMetadata({
    title: outcome.data.name,
    description: outcome.data.description,
    path: `/marketplaces/${slug}`,
  });
}

export default async function MarketplaceDetailPage({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const marketplaceOutcome = await loadMarketplace(slug);
  if (!marketplaceOutcome.ok) {
    if (marketplaceOutcome.error instanceof ApiError && marketplaceOutcome.error.status === 404) {
      notFound();
    }
    return (
      <ErrorState
        title="Market unavailable"
        description={describeFetchError(marketplaceOutcome)}
        retryHref={`/marketplaces/${slug}`}
      />
    );
  }
  const marketplace = marketplaceOutcome.data;

  const sellersOutcome = await loadMarketplaceSellers(slug);
  const sellers = sellersOutcome.ok ? sellersOutcome.data : null;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">{marketplace.name}</h1>
        <p className="mt-2 text-[var(--muted)]">{marketplace.description}</p>
        <p className="mt-3 text-sm text-[var(--muted)]">
          {marketplace.city}
          {marketplace.seller_count != null ? ` · ${marketplace.seller_count} sellers` : ""}
        </p>
      </div>

      {!sellersOutcome.ok ? (
        <ErrorState
          title="Sellers unavailable"
          description={describeFetchError(sellersOutcome)}
          retryHref={`/marketplaces/${slug}`}
        />
      ) : !sellers || sellers.length === 0 ? (
        <EmptyState
          title="No sellers in this market yet"
          description="Explore other markets or search the full directory."
          actionHref="/sellers"
          actionLabel="Browse businesses"
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {sellers.map((seller) => (
            <SellerCard key={seller.id} seller={seller} />
          ))}
        </div>
      )}

      <Link href="/search" className="inline-flex text-sm font-semibold text-[var(--primary)]">
        Search all listings →
      </Link>
    </div>
  );
}
