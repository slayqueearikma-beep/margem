import { notFound } from "next/navigation";
import { getLocale, getTranslations } from "next-intl/server";
import { SellerCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { ApiError } from "@/lib/api";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadMarketplace, loadMarketplaceSellers } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type MarketplaceDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const t = await getTranslations("meta");
  const locale = await getLocale();
  const outcome = await loadMarketplace(slug);
  if (!outcome.ok) {
    return buildPageMetadata({
      title: t("marketNotFound.title"),
      description: t("marketNotFound.description"),
      path: `/marketplaces/${slug}`,
      locale,
    });
  }
  return buildPageMetadata({
    title: outcome.data.name,
    description: outcome.data.description,
    path: `/marketplaces/${slug}`,
    locale,
  });
}

export default async function MarketplaceDetailPage({ params }: MarketplaceDetailProps) {
  const { slug } = await params;
  const t = await getTranslations("marketplaces");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");
  const tFormat = await getTranslations("format");

  const marketplaceOutcome = await loadMarketplace(slug);
  if (!marketplaceOutcome.ok) {
    if (marketplaceOutcome.error instanceof ApiError && marketplaceOutcome.error.status === 404) {
      notFound();
    }
    return (
      <ErrorState
        title={t("unavailableTitle")}
        description={describeFetchErrorMessage(marketplaceOutcome, (key, values) =>
          tErrors(key, values),
        )}
        retryHref={`/marketplaces/${slug}`}
        retryLabel={tCommon("tryAgain")}
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
          {marketplace.seller_count != null
            ? ` · ${tFormat("sellersCount", { count: marketplace.seller_count })}`
            : ""}
        </p>
      </div>

      {!sellersOutcome.ok ? (
        <ErrorState
          title={t("sellersUnavailableTitle")}
          description={describeFetchErrorMessage(sellersOutcome, (key, values) =>
            tErrors(key, values),
          )}
          retryHref={`/marketplaces/${slug}`}
          retryLabel={tCommon("tryAgain")}
        />
      ) : !sellers || sellers.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          description={t("emptyDescription")}
          actionHref="/sellers"
          actionLabel={tCommon("browseBusinesses")}
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {sellers.map((seller) => (
            <SellerCard key={seller.id} seller={seller} />
          ))}
        </div>
      )}

      <Link href="/search" className="inline-flex text-sm font-semibold text-[var(--primary)]">
        {t("searchAllListings")}
      </Link>
    </div>
  );
}
