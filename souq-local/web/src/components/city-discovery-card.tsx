import Link from "next/link";
import type { GeographyCity } from "@/lib/types";

const ACTIVE_CITY_SLUG = "casablanca";

function isActiveLaunchCity(city: GeographyCity): boolean {
  return (
    city.slug.toLowerCase() === ACTIVE_CITY_SLUG ||
    city.name_en.trim().toLowerCase() === "casablanca"
  );
}

const cardClassName =
  "relative overflow-hidden rounded-2xl border border-[var(--border)] bg-white p-6";

type CityDiscoveryCardProps = {
  city: GeographyCity;
};

export function CityDiscoveryCard({ city }: CityDiscoveryCardProps) {
  const active = isActiveLaunchCity(city);

  if (active) {
    return (
      <Link
        href={`/cities/${city.slug}`}
        className={`${cardClassName} transition hover:border-[var(--primary)] hover:shadow-sm`}
      >
        <h2 className="text-lg font-semibold">{city.name_en}</h2>
        {city.region ? (
          <p className="mt-2 text-sm text-[var(--muted)]">{city.region}</p>
        ) : null}
      </Link>
    );
  }

  return (
    <div className={cardClassName} aria-label={`${city.name_en} — coming soon`}>
      <span className="city-coming-soon-ribbon" aria-hidden="true">
        COMING SOON
      </span>
      <h2 className="text-lg font-semibold">{city.name_en}</h2>
      {city.region ? (
        <p className="mt-2 text-sm text-[var(--muted)]">{city.region}</p>
      ) : null}
    </div>
  );
}

export function isLaunchCityActive(city: GeographyCity): boolean {
  return isActiveLaunchCity(city);
}
