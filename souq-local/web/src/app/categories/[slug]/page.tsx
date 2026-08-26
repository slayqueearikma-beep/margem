import Link from "next/link";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { EmptyState } from "@/components/states";
import { fetchCategories, fetchSearch, fetchServices } from "@/lib/marketplace-api";
import { categoryLabel } from "@/lib/format";
import { buildPageMetadata } from "@/lib/seo";
import { notFound } from "next/navigation";

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
  const categories = await fetchCategories().catch(() => []);
  const category = categories.find((item) => item.slug === slug);
  if (!category) notFound();

  const [search, services] = await Promise.all([
    fetchSearch({ mode: "all", category: slug, limit: 12 }).catch(() => null),
    fetchServices({ category: slug, limit: 12 }).catch(() => null),
  ]);

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

      {!search && !services ? (
        <EmptyState
          title="Category unavailable"
          description="We couldn't load listings for this category."
          actionHref={`/categories/${slug}`}
          actionLabel="Retry"
        />
      ) : null}

      {search && search.products.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Products</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {search.products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        </section>
      ) : null}

      {services && services.items.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Services</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {services.items.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        </section>
      ) : null}

      {search && search.sellers.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Businesses</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {search.sellers.map((seller) => (
              <SellerCard key={seller.id} seller={seller} />
            ))}
          </div>
        </section>
      ) : null}

      {search &&
      search.products.length === 0 &&
      search.sellers.length === 0 &&
      (!services || services.items.length === 0) ? (
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
