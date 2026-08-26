import { CityDiscoveryCard } from "@/components/city-discovery-card";
import { LAUNCH_CITIES } from "@/lib/config";
import { slugifyCity } from "@/lib/format";
import { fetchGeographyCities } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";
import type { GeographyCity } from "@/lib/types";

export const metadata = buildPageMetadata({
  title: "City discovery",
  description: "Explore Dribex marketplace listings by city and location.",
  path: "/cities",
});

export default async function CitiesPage() {
  const geography = await fetchGeographyCities();
  const cities: GeographyCity[] =
    geography?.items?.filter((city) => city.is_active !== false) ??
    LAUNCH_CITIES.map((name) => ({
      id: slugifyCity(name),
      slug: slugifyCity(name),
      name_en: name,
    }));

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Cities</h1>
        <p className="mt-2 text-[var(--muted)]">
          Discover marketplace activity by city. Listings currently focus on active launch cities.
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cities.map((city) => (
          <CityDiscoveryCard key={city.id} city={city} />
        ))}
      </div>
    </div>
  );
}
