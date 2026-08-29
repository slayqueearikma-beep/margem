import { AdvertisementBanner } from "@/components/advertisement-banner";
import { ServiceCard } from "@/components/listing-cards";
import { PaginationNav } from "@/components/pagination";
import { EmptyState, ErrorState } from "@/components/states";
import { describeFetchError, loadActiveAdvertisements, loadSearch } from "@/lib/marketplace-fetch";
import { buildPageMetadata } from "@/lib/seo";

export const metadata = buildPageMetadata({
  title: "Service listings",
  description: "Browse public services offered by Dribex businesses.",
  path: "/services",
});

type ServicesPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ServicesPage({ searchParams }: ServicesPageProps) {
  const params = await searchParams;
  const category = typeof params.category === "string" ? params.category : undefined;
  const city = typeof params.city === "string" ? params.city : undefined;
  const q = typeof params.q === "string" ? params.q : undefined;
  const offset = Number(typeof params.offset === "string" ? params.offset : 0);
  const limit = 24;

  const outcome = await loadSearch({
    mode: "services",
    category,
    city,
    q,
    offset,
    limit,
  });
  const ads = await loadActiveAdvertisements("service_listing", {
    city,
    categorySlug: category,
    listingType: "service",
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Services</h1>
        <p className="mt-2 text-[var(--muted)]">
          Discover services from local businesses on Dribex.
        </p>
      </div>

      {ads[0] ? <AdvertisementBanner ad={ads[0]} placement="service_listing" /> : null}

      {!outcome.ok ? (
        <ErrorState
          title="Services unavailable"
          description={describeFetchError(outcome)}
          retryHref="/services"
        />
      ) : outcome.data.services.length === 0 ? (
        <EmptyState
          title="No services found"
          description="Try another category or browse business profiles for offerings."
          actionHref="/sellers"
          actionLabel="Browse businesses"
        />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {outcome.data.services.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
          <PaginationNav
            basePath="/services"
            offset={outcome.data.offset}
            limit={outcome.data.limit}
            hasMore={outcome.data.has_more}
            total={outcome.data.total_services}
            params={{ category, city, q }}
          />
        </>
      )}
    </div>
  );
}
