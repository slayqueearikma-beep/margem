import { getLocale, getTranslations } from "next-intl/server";
import { EmptyState, ErrorState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { categoryLabel } from "@/lib/format";
import { describeFetchErrorMessage } from "@/lib/i18n-errors";
import { loadCategories } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("categories.title"),
    description: t("categories.description"),
    path: "/categories",
    locale,
  });
}

export default async function CategoriesPage() {
  const locale = await getLocale();
  const t = await getTranslations("categories");
  const tCommon = await getTranslations("common");
  const tErrors = await getTranslations("errors");

  const outcome = await loadCategories();

  if (!outcome.ok) {
    return (
      <ErrorState
        title={t("unavailableTitle")}
        description={describeFetchErrorMessage(outcome, (key, values) => tErrors(key, values))}
        retryHref="/categories"
        retryLabel={tCommon("tryAgain")}
      />
    );
  }

  const categories = outcome.data;

  if (categories.length === 0) {
    return (
      <EmptyState
        title={t("emptyTitle")}
        description={t("emptyDescription")}
        actionHref="/"
        actionLabel={tCommon("backHomeShort")}
      />
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-2 text-[var(--muted)]">{t("description")}</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {categories.map((category) => (
          <Link
            key={category.id}
            href={`/categories/${category.slug}`}
            className="rounded-2xl border border-[var(--border)] bg-white p-6 transition hover:border-[var(--primary)] hover:shadow-sm"
          >
            <p className="text-lg font-semibold">{categoryLabel(category, locale)}</p>
            <p className="mt-2 text-sm text-[var(--muted)]">{category.slug}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
