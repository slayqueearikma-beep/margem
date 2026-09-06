import { getLocale, getTranslations } from "next-intl/server";
import { SellerCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("sellers.title"),
    description: t("sellers.description"),
    path: "/sellers",
    locale,
  });
}

type SellersPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function SellersPage({ searchParams }: SellersPageProps) {
  const params = await searchParams;
  const t = await getTranslations("sellers");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

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
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-2 text-[var(--muted)]">{t("description")}</p>
      </div>

      {!outcome.ok ? (
        <ErrorState
          title={t("unavailableTitle")}
          description={describeFetchErrorMessage(outcome, (key, values) => tErrors(key, values))}
          retryHref="/sellers"
          retryLabel={tCommon("tryAgain")}
        />
      ) : outcome.data.sellers.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          description={t("emptyDescription")}
          actionHref="/search?mode=sellers"
          actionLabel={tCommon("searchBusinesses")}
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
