import Link from "next/link";
import { EmptyState, ErrorState } from "@/components/states";
import { categoryLabel } from "@/lib/format";
import { describeFetchError, loadCategories } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export const metadata = buildPageMetadata({
  title: "Browse categories",
  description: "Explore Dribex marketplace categories for products and services.",
  path: "/categories",
});

export default async function CategoriesPage() {
  const outcome = await loadCategories();

  if (!outcome.ok) {
    return (
      <ErrorState
        title="Categories unavailable"
        description={describeFetchError(outcome)}
        retryHref="/categories"
      />
    );
  }

  const categories = outcome.data;

  if (categories.length === 0) {
    return (
      <EmptyState
        title="No categories available"
        description="The marketplace catalog has no categories yet."
        actionHref="/"
        actionLabel="Back home"
      />
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Categories</h1>
        <p className="mt-2 text-[var(--muted)]">
          Browse listings grouped by marketplace category.
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {categories.map((category) => (
          <Link
            key={category.id}
            href={`/categories/${category.slug}`}
            className="rounded-2xl border border-[var(--border)] bg-white p-6 transition hover:border-[var(--primary)] hover:shadow-sm"
          >
            <p className="text-lg font-semibold">{categoryLabel(category)}</p>
            <p className="mt-2 text-sm text-[var(--muted)]">{category.slug}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
