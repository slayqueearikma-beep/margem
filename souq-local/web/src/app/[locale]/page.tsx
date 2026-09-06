import { Suspense } from "react";
import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { SearchBar } from "@/components/search-bar";
import { EmptyState, ErrorState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { BRAND } from "@/lib/config";
import { categoryLabel } from "@/lib/format";
import {
  loadActiveAdvertisements,
  loadCategories,
  loadMarketplaces,
  loadSearch,
} from "@/lib/marketplace-fetch";
import {
  describeFetchErrorMessage,
  serviceUnavailableDescription,
} from "@/lib/i18n-errors";
import { buildPageMetadata } from "@/lib/seo";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("home.title"),
    description: t("home.description"),
    path: "/",
    locale,
  });
}

export default async function HomePage() {
  const locale = await getLocale();
  const t = await getTranslations("home");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const [searchOutcome, categoriesOutcome, marketplacesOutcome, ads] = await Promise.all([
    loadSearch({ mode: "all", limit: 8 }),
    loadCategories(),
    loadMarketplaces(),
    loadActiveAdvertisements("homepage_top"),
  ]);

  const search = searchOutcome.ok ? searchOutcome.data : null;
  const searchError = searchOutcome.ok ? null : searchOutcome;
  const categories = categoriesOutcome.ok ? categoriesOutcome.data : [];
  const categoriesError = categoriesOutcome.ok ? null : categoriesOutcome;
  const marketplaces = marketplacesOutcome.ok ? marketplacesOutcome.data : null;

  const apiFailure = searchError || categoriesError;

  return (
    <div className="space-y-12">
      {apiFailure ? (
        <ErrorState
          title={t("apiUnavailableTitle")}
          description={serviceUnavailableDescription(apiFailure, (key, values) =>
            tErrors(key, values),
          )}
          retryHref="/"
          retryLabel={tCommon("tryAgain")}
        />
      ) : null}

      <section className="overflow-hidden rounded-3xl bg-gradient-to-br from-[var(--cream)] via-white to-[var(--primary-muted)] px-6 py-10 sm:px-10">
        <div className="max-w-2xl">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-[var(--primary)]">
            {t("publicMarketplace")}
          </p>
          <h1 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">
            {t("heroTitle", { brand: BRAND.name })}
          </h1>
          <p className="mt-4 text-base text-[var(--muted)]">{t("heroDescription")}</p>
        </div>
        <div className="mt-8">
          <Suspense fallback={<div className="h-16 animate-pulse rounded-2xl bg-white/70" />}>
            <SearchBar />
          </Suspense>
        </div>
      </section>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="homepage_top" /> : null}

      {categories.length > 0 ? (
        <section>
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold">{t("shopByCategory")}</h2>
              <p className="text-sm text-[var(--muted)]">{t("shopByCategorySubtitle")}</p>
            </div>
            <Link href="/categories" className="text-sm font-semibold text-[var(--primary)]">
              {tCommon("viewAll")}
            </Link>
          </div>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {categories.slice(0, 8).map((category) => (
              <Link
                key={category.id}
                href={`/categories/${category.slug}`}
                className="rounded-2xl border border-[var(--border)] bg-white px-4 py-5 transition hover:border-[var(--primary)] hover:shadow-sm"
              >
                <p className="font-semibold">{categoryLabel(category, locale)}</p>
                <p className="mt-1 text-xs uppercase tracking-wide text-[var(--muted)]">
                  {category.slug}
                </p>
              </Link>
            ))}
          </div>
        </section>
      ) : categoriesError ? (
        <ErrorState
          title={t("categoriesUnavailable")}
          description={describeFetchErrorMessage(categoriesError, (key, values) =>
            tErrors(key, values),
          )}
          retryHref="/"
          retryLabel={tCommon("tryAgain")}
        />
      ) : null}

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">{t("featuredProducts")}</h2>
            <p className="text-sm text-[var(--muted)]">{t("featuredProductsSubtitle")}</p>
          </div>
          <Link href="/products" className="text-sm font-semibold text-[var(--primary)]">
            {tCommon("seeAllProducts")}
          </Link>
        </div>
        {searchError ? (
          <ErrorState
            title={t("productsUnavailable")}
            description={describeFetchErrorMessage(searchError, (key, values) =>
              tErrors(key, values),
            )}
            retryHref="/"
            retryLabel={tCommon("tryAgain")}
          />
        ) : search && search.products.length === 0 ? (
          <EmptyState
            title={t("noProductsTitle")}
            description={t("noProductsDescription")}
            actionHref="/sellers"
            actionLabel={tCommon("browseBusinesses")}
          />
        ) : search ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : null}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">{t("featuredServices")}</h2>
            <p className="text-sm text-[var(--muted)]">{t("featuredServicesSubtitle")}</p>
          </div>
          <Link href="/services" className="text-sm font-semibold text-[var(--primary)]">
            {tCommon("seeAllServices")}
          </Link>
        </div>
        {searchError ? null : search && search.services.length > 0 ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.services.slice(0, 4).map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        ) : search ? (
          <EmptyState
            title={t("noServicesTitle")}
            description={t("noServicesDescription")}
            actionHref="/sellers"
            actionLabel={tCommon("browseBusinesses")}
          />
        ) : null}
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">{t("topBusinesses")}</h2>
            <p className="text-sm text-[var(--muted)]">{t("topBusinessesSubtitle")}</p>
          </div>
          <Link href="/sellers" className="text-sm font-semibold text-[var(--primary)]">
            {tCommon("viewDirectory")}
          </Link>
        </div>
        {searchError ? (
          <ErrorState
            title={t("businessDirectoryUnavailable")}
            description={describeFetchErrorMessage(searchError, (key, values) =>
              tErrors(key, values),
            )}
            retryHref="/"
            retryLabel={tCommon("tryAgain")}
          />
        ) : search && search.sellers.length > 0 ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {search.sellers.slice(0, 6).map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
        ) : search ? (
          <EmptyState
            title={t("noBusinessesTitle")}
            description={t("noBusinessesDescription")}
            actionHref="/search?mode=sellers"
            actionLabel={tCommon("searchMarketplace")}
          />
        ) : null}
      </section>

      {marketplaces && marketplaces.length > 0 ? (
        <section>
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold">{t("markets")}</h2>
              <p className="text-sm text-[var(--muted)]">{t("marketsSubtitle")}</p>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {marketplaces.slice(0, 6).map((marketplace) => (
              <Link
                key={marketplace.id}
                href={`/marketplaces/${marketplace.slug}`}
                className="rounded-2xl border border-[var(--border)] bg-white p-5 transition hover:shadow-sm"
              >
                <h3 className="font-semibold">{marketplace.name}</h3>
                <p className="mt-2 line-clamp-2 text-sm text-[var(--muted)]">
                  {marketplace.description}
                </p>
                <p className="mt-3 text-xs text-[var(--muted)]">
                  {t("sellersCountInMarket", {
                    count: marketplace.seller_count ?? 0,
                    city: marketplace.city,
                  })}
                </p>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
