import { notFound } from "next/navigation";
import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { categoryLabel } from "@/lib/format";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadActiveAdvertisements, loadCategories, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type CategoryDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: CategoryDetailProps) {
  const { slug } = await params;
  const t = await getTranslations("meta");
  const locale = await getLocale();
  const categoriesOutcome = await loadCategories();
  const category = categoriesOutcome.ok
    ? categoriesOutcome.data.find((item) => item.slug === slug)
    : undefined;
  const categoryName = category ? categoryLabel(category, locale) : slug.replace(/-/g, " ");

  return buildPageMetadata({
    title: t("categoryListings.title", { category: categoryName }),
    description: t("categoryListings.description", { category: categoryName }),
    path: `/categories/${slug}`,
    locale,
  });
}

export default async function CategoryDetailPage({ params }: CategoryDetailProps) {
  const { slug } = await params;
  const locale = await getLocale();
  const t = await getTranslations("categories");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const categoriesOutcome = await loadCategories();
  if (!categoriesOutcome.ok) {
    return (
      <ErrorState
        title={t("detailUnavailableTitle")}
        description={describeFetchErrorMessage(categoriesOutcome, (key, values) =>
          tErrors(key, values),
        )}
        retryHref={`/categories/${slug}`}
        retryLabel={tCommon("tryAgain")}
      />
    );
  }

  const category = categoriesOutcome.data.find((item) => item.slug === slug);
  if (!category) notFound();

  const searchOutcome = await loadSearch({ mode: "all", category: slug, limit: 12 });
  if (!searchOutcome.ok) {
    return (
      <div className="space-y-10">
        <div>
          <Link href="/categories" className="text-sm font-semibold text-[var(--primary)]">
            {tCommon("allCategories")}
          </Link>
          <h1 className="mt-3 text-3xl font-bold tracking-tight">
            {categoryLabel(category, locale)}
          </h1>
        </div>
        <ErrorState
          title={t("listingsUnavailableTitle")}
          description={describeFetchErrorMessage(searchOutcome, (key, values) =>
            tErrors(key, values),
          )}
          retryHref={`/categories/${slug}`}
          retryLabel={tCommon("tryAgain")}
        />
      </div>
    );
  }

  const search = searchOutcome.data;
  const ads = await loadActiveAdvertisements("category_page", { categorySlug: slug });

  return (
    <div className="space-y-10">
      <div>
        <Link href="/categories" className="text-sm font-semibold text-[var(--primary)]">
          {tCommon("allCategories")}
        </Link>
        <h1 className="mt-3 text-3xl font-bold tracking-tight">
          {categoryLabel(category, locale)}
        </h1>
        <p className="mt-2 text-[var(--muted)]">
          {t("taggedDescription", { slug: category.slug })}
        </p>
      </div>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="category_page" /> : null}

      {search.products.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">{tCommon("products")}</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        </section>
      ) : null}

      {search.services.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">{tCommon("services")}</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.services.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        </section>
      ) : null}

      {search.sellers.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">{tCommon("businesses")}</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {search.sellers.map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
        </section>
      ) : null}

      {search.products.length === 0 &&
      search.sellers.length === 0 &&
      search.services.length === 0 ? (
        <EmptyState
          title={t("emptyListingsTitle")}
          description={t("emptyListingsDescription")}
          actionHref="/search"
          actionLabel={tCommon("searchMarketplace")}
        />
      ) : null}
    </div>
  );
}
