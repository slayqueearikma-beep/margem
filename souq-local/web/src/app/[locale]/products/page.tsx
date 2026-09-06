import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ProductCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadActiveAdvertisements, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("products.title"),
    description: t("products.description"),
    path: "/products",
    locale,
  });
}

type ProductsPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ProductsPage({ searchParams }: ProductsPageProps) {
  const params = await searchParams;
  const t = await getTranslations("products");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const category = typeof params.category === "string" ? params.category : undefined;
  const city = typeof params.city === "string" ? params.city : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const outcome = await loadSearch({
    mode: "products",
    category,
    city,
    offset,
    limit,
  });
  const ads = await loadActiveAdvertisements("products_listing", { city, categorySlug: category });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-2 text-[var(--muted)]">{t("description")}</p>
      </div>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="products_listing" /> : null}

      {!outcome.ok ? (
        <ErrorState
          title={t("unavailableTitle")}
          description={describeFetchErrorMessage(outcome, (key, values) => tErrors(key, values))}
          retryHref="/products"
          retryLabel={tCommon("tryAgain")}
        />
      ) : outcome.data.products.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          description={t("emptyDescription")}
          actionHref="/categories"
          actionLabel={tCommon("browseCategories")}
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {outcome.data.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
          <PaginationNav
            basePath="/products"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={outcome.data.total_products}
            params={{ category, city }}
          />
        </>
      )}
    </div>
  );
}
