import Link from "next/link";
import { notFound } from "next/navigation";
import { SellerCard } from "@/components/listing-cards";
import { EmptyState } from "@/components/states";
import { fetchMarketplace, fetchMarketplaceSellers } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";

type MarketplaceDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const marketplace = await fetchMarketplace(slug);
  if (!marketplace) {
    return buildPageMetadata({
      title: "Market not found",
      description: "This marketplace is unavailable.",
      path: `/marketplaces/${slug}`,
    });
  }
  return buildPageMetadata({
    title: marketplace.name,
    description: marketplace.description,
    path: `/marketplaces/${slug}`,
  });
}

export default async function MarketplaceDetailPage({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const marketplace = await fetchMarketplace(slug);
  if (!marketplace) notFound();

  const sellers = await fetchMarketplaceSellers(slug);

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

      {!sellers || sellers.length === 0 ? (
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
