import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductCard, SellerCard, ServiceCard } from "@/components/listing-cards";
import { EmptyState, ErrorState } from "@/components/states";
import { cityFromSlug } from "@/lib/format";
import { isActiveLaunchCity } from "@/lib/launch-cities";
import { ACTIVE_LAUNCH_CITY_NAME } from "@/lib/launch-cities";
import { describeFetchError, loadGeographyCities, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

type CityDetailProps = {
  params: Promise<{ slug: string }>;
};

export async function generateMetadata({ params }: CityDetailProps) {
  const { slug } = await params;
  const cityName = slug.replace(/-/g, " ");
  return buildPageMetadata({
    title: `${cityName} marketplace`,
    description: `Browse Dribex products and businesses in ${cityName}.`,
    path: `/cities/${slug}`,
  });
}

export default async function CityDetailPage({ params }: CityDetailProps) {
  const { slug } = await params;
  const geographyOutcome = await loadGeographyCities();
  const geography = geographyOutcome.ok ? geographyOutcome.data : null;
  const geoCity = geography?.items?.find((city) => city.slug === slug);
  const cityName =
    geoCity?.name_en || cityFromSlug(slug, [ACTIVE_LAUNCH_CITY_NAME]) || slug.replace(/-/g, " ");

  if (!cityName) notFound();

  if (geoCity && !isActiveLaunchCity(geoCity)) {
    return (
      <div className="space-y-8">
        <div>
          <Link href="/cities" className="text-sm font-semibold text-[var(--primary)]">
            ← All cities
          </Link>
          <h1 className="mt-3 text-3xl font-bold tracking-tight">{cityName}</h1>
          <p className="mt-2 text-[var(--muted)]">
            Dribex marketplace listings in {cityName} are coming soon.
          </p>
        </div>
        <EmptyState
          title="Coming soon"
          description={`${cityName} is not an active launch city yet. Explore listings in ${ACTIVE_LAUNCH_CITY_NAME} today.`}
          actionHref={`/cities/casablanca`}
          actionLabel={`Browse ${ACTIVE_LAUNCH_CITY_NAME}`}
        />
      </div>
    );
  }

  const searchOutcome = await loadSearch({ mode: "all", city: cityName, limit: 12 });

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

      {!searchOutcome.ok ? (
        <ErrorState
          title="City listings unavailable"
          description={describeFetchError(searchOutcome)}
          retryHref={`/cities/${slug}`}
        />
      ) : (
        <>
          {searchOutcome.data.products.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Products in {cityName}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {searchOutcome.data.products.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </section>
          ) : null}

          {searchOutcome.data.services.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Services in {cityName}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {searchOutcome.data.services.map((service) => (
                  <ServiceCard key={service.id} service={service} />
                ))}
              </div>
            </section>
          ) : null}

          {searchOutcome.data.sellers.length > 0 ? (
            <section className="space-y-4">
              <h2 className="text-lg font-semibold">Businesses in {cityName}</h2>
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
