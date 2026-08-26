import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { categoryLabel } from "@/lib/format";
import { describeFetchError, loadCategories, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type CategoryDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: CategoryDetailProps) {
  const { slug } = await params;
  return buildPageMetadata({
    title: `${slug.replace(/-/g, " ")} listings`,
    description: `Browse Dribex marketplace listings in the ${slug} category.`,
    path: `/categories/${slug}`,
  });
}

export default async function CategoryDetailPage({ params }: CategoryDetailProps) {
  const { slug } = await params;
  const categoriesOutcome = await loadCategories();
  if (!categoriesOutcome.ok) {
    return (
      <ErrorState
        title="Category unavailable"
        description={describeFetchError(categoriesOutcome)}
        retryHref={`/categories/${slug}`}
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
            ← All categories
          </Link>
          <h1 className="mt-3 text-3xl font-bold tracking-tight">{categoryLabel(category)}</h1>
        </div>
        <ErrorState
          title="Category listings unavailable"
          description={describeFetchError(searchOutcome)}
          retryHref={`/categories/${slug}`}
        />
      </div>
    );
  }

  const search = searchOutcome.data;

  return (
    <div className="space-y-10">
      <div>
        <Link href="/categories" className="text-sm font-semibold text-[var(--primary)]">
          ← All categories
        </Link>
        <h1 className="mt-3 text-3xl font-bold tracking-tight">{categoryLabel(category)}</h1>
        <p className="mt-2 text-[var(--muted)]">
          Products, services, and businesses tagged with {category.slug}.
        </p>
      </div>

      {search.products.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Products</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        </section>
      ) : null}

      {search.services.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Services</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.services.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        </section>
      ) : null}

      {search.sellers.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Businesses</h2>
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
          title="No listings in this category"
          description="Try another category or search across the full marketplace."
          actionHref="/search"
          actionLabel="Search marketplace"
        />
      ) : null}
    </div>
  );
}
