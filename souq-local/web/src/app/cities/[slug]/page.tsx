import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductCard, SellerCard } from "@/components/listing-cards";
import { EmptyState } from "@/components/states";
import { LAUNCH_CITIES } from "@/lib/config";
import { cityFromSlug } from "@/lib/format";
import { fetchGeographyCities, fetchSearch } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";

type CityDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: CityDetailProps) {
  const { slug } = await params;
  const cityName = cityFromSlug(slug, LAUNCH_CITIES) || slug.replace(/-/g, " ");
  return buildPageMetadata({
    title: `${cityName} marketplace`,
    description: `Browse Dribex products and businesses in ${cityName}.`,
    path: `/cities/${slug}`,
  });
}

export default async function CityDetailPage({ params }: CityDetailProps) {
  const { slug } = await params;
  const geography = await fetchGeographyCities();
  const geoCity = geography?.items?.find((city) => city.slug === slug);
  const cityName =
    geoCity?.name_en || cityFromSlug(slug, LAUNCH_CITIES) || slug.replace(/-/g, " ");

  if (!cityName) notFound();

  const results = await fetchSearch({ mode: "all", city: cityName, limit: 12 }).catch(
    () => null,
  );

  return (
    <div className="space-y-10">
      <div>
        <Link href="/cities" className="text-sm font-semibold text-[var(--primary)]">
          ← All cities
        </Link>
        <h1 className="mt-3 text-3xl font-bold tracking-tight">{cityName}</h1>
        <p className="mt-2 text-[var(--muted)]">
          Public marketplace listings available in {cityName}.
        </p>
      </div>

      {!results ? (
        <EmptyState
          title="City listings unavailable"
          description="We couldn't load listings for this city."
          actionHref={`/cities/${slug}`}
          actionLabel="Retry"
        />
      ) : (
        <>
          {results.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Products in {cityName}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {results.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {results.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Businesses in {cityName}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {results.sellers.map((seller) => (
                  <SellerCard key={seller.id} seller={seller} />
                ))}
              </div>
            </section>
          ) : null}

          {results.products.length === 0 && results.sellers.length === 0 ? (
            <EmptyState
              title={`No public listings in ${cityName} yet`}
              description="Check back soon or explore other cities."
              actionHref="/search"
              actionLabel="Search marketplace"
            />
          ) : null}
        </>
      )}
    </div>
  );
}
