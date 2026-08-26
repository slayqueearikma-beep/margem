import { ServiceCard } from "@/components/listing-cards";
import { EmptyState } from "@/components/states";
import { fetchServices } from "@/lib/marketplace-api";
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

  const results = await fetchServices({
    category,
    city,
    q,
    offset,
    limit: 24,
  }).catch(() => null);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Services</h1>
        <p className="mt-2 text-[var(--muted)]">
          Discover services from local businesses on Dribex.
        </p>
      </div>

      {!results ? (
        <EmptyState
          title="Services unavailable"
          description="We couldn't load service listings from the API."
          actionHref="/services"
          actionLabel="Retry"
        />
      ) : results.items.length === 0 ? (
        <EmptyState
          title="No services found"
          description="Try another category or browse business profiles for offerings."
          actionHref="/sellers"
          actionLabel="Browse businesses"
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {results.items.map((service) => (
            <ServiceCard key={service.id} service={service} />
          ))}
        </div>
      )}
    </div>
  );
}
