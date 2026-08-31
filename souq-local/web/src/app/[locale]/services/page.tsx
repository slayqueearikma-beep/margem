import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ServiceCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadActiveAdvertisements, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("services.title"),
    description: t("services.description"),
    path: "/services",
    locale,
  });
}

type ServicesPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ServicesPage({ searchParams }: ServicesPageProps) {
  const params = await searchParams;
  const t = await getTranslations("services");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const category = typeof params.category === "string" ? params.category : undefined;
  const city = typeof params.city === "string" ? params.city : undefined;
  const q = typeof params.q === "string" ? params.q : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const outcome = await loadSearch({
    mode: "services",
    category,
    city,
    q,
    offset,
    limit,
  });
  const ads = await loadActiveAdvertisements("service_listing", {
    city,
    categorySlug: category,
    listingType: "service",
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-2 text-[var(--muted)]">{t("description")}</p>
      </div>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="service_listing" /> : null}

      {!outcome.ok ? (
        <ErrorState
          title={t("unavailableTitle")}
          description={describeFetchErrorMessage(outcome, (key, values) => tErrors(key, values))}
          retryHref="/services"
          retryLabel={tCommon("tryAgain")}
        />
      ) : outcome.data.services.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          description={t("emptyDescription")}
          actionHref="/sellers"
          actionLabel={tCommon("browseBusinesses")}
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {outcome.data.services.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
          <PaginationNav
            basePath="/services"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={outcome.data.total_services}
            params={{ category, city, q }}
          />
        </>
      )}
    </div>
  );
}
