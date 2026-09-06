import { notFound } from "next/navigation";
import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { cityDisplayName } from "@/lib/city-name";
import { cityFromSlug } from "@/lib/format";
import { isActiveLaunchCity } from "@/lib/launch-cities";
import { ACTIVE_LAUNCH_CITY_NAME } from "@/lib/launch-cities";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadActiveAdvertisements, loadGeographyCities, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type CityDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: CityDetailProps) {
  const { slug } = await params;
  const t = await getTranslations("meta");
  const locale = await getLocale();
  const geographyOutcome = await loadGeographyCities();
  const geography = geographyOutcome.ok ? geographyOutcome.data : null;
  const geoCity = geography?.items?.find((city) => city.slug === slug);
  const cityName =
    geoCity
      ? cityDisplayName(geoCity, locale)
      : cityFromSlug(slug, [ACTIVE_LAUNCH_CITY_NAME]) || slug.replace(/-/g, " ");

  return buildPageMetadata({
    title: t("cityMarketplace.title", { cityName }),
    description: t("cityMarketplace.description", { cityName }),
    path: `/cities/${slug}`,
    locale,
  });
}

export default async function CityDetailPage({ params }: CityDetailProps) {
  const { slug } = await params;
  const locale = await getLocale();
  const t = await getTranslations("cities");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const geographyOutcome = await loadGeographyCities();
  const geography = geographyOutcome.ok ? geographyOutcome.data : null;
  const geoCity = geography?.items?.find((city) => city.slug === slug);
  const cityName =
    geoCity
      ? cityDisplayName(geoCity, locale)
      : cityFromSlug(slug, [ACTIVE_LAUNCH_CITY_NAME]) || slug.replace(/-/g, " ");

  if (!cityName) notFound();

  if (geoCity && !isActiveLaunchCity(geoCity)) {
    return (
      <div className="space-y-8">
        <div>
          <Link href="/cities" className="text-sm font-semibold text-[var(--primary)]">
            {tCommon("allCities")}
          </Link>
          <h1 className="mt-3 text-3xl font-bold tracking-tight">{cityName}</h1>
          <p className="mt-2 text-[var(--muted)]">
            {t("comingSoonDescription", { cityName })}
          </p>
        </div>
        <EmptyState
          title={t("comingSoonEmptyTitle")}
          description={t("comingSoonEmptyDescription", {
            cityName,
            activeCity: ACTIVE_LAUNCH_CITY_NAME,
          })}
          actionHref="/cities/casablanca"
          actionLabel={t("browseActiveCity", { activeCity: ACTIVE_LAUNCH_CITY_NAME })}
        />
      </div>
    );
  }

  const searchOutcome = await loadSearch({ mode: "all", city: cityName, limit: 12 });
  const ads = await loadActiveAdvertisements("city_page", { city: slug });

  return (
    <div className="space-y-10">
      <div>
        <Link href="/cities" className="text-sm font-semibold text-[var(--primary)]">
          {tCommon("allCities")}
        </Link>
        <h1 className="mt-3 text-3xl font-bold tracking-tight">{cityName}</h1>
        <p className="mt-2 text-[var(--muted)]">
          {t("listingsDescription", { cityName })}
        </p>
      </div>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="city_page" /> : null}

      {!searchOutcome.ok ? (
        <ErrorState
          title={t("listingsUnavailableTitle")}
          description={describeFetchErrorMessage(searchOutcome, (key, values) =>
            tErrors(key, values),
          )}
          retryHref={`/cities/${slug}`}
          retryLabel={tCommon("tryAgain")}
        />
      ) : (
        <>
          {searchOutcome.data.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">{t("productsInCity", { cityName })}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {searchOutcome.data.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {searchOutcome.data.services.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">{t("servicesInCity", { cityName })}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {searchOutcome.data.services.map((service) => (
                  <ServiceCard key={service.id} service={service} />
                ))}
              </div>
            </section>
          ) : null}

          {searchOutcome.data.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">{t("businessesInCity", { cityName })}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {searchOutcome.data.sellers.map((seller) => (
                  <SellerCard key={seller.id} seller={seller} />
                ))}
              </div>
            </section>
          ) : null}

          {searchOutcome.data.products.length === 0 &&
          searchOutcome.data.services.length === 0 &&
          searchOutcome.data.sellers.length === 0 ? (
            <EmptyState
              title={t("emptyListingsTitle", { cityName })}
              description={t("emptyListingsDescription")}
              actionHref="/search"
              actionLabel={tCommon("searchMarketplace")}
            />
          ) : null}
        </>
      )}
    </div>
  );
}
