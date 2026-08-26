import Link from "next/link";
import { isActiveLaunchCity } from "@/lib/launch-cities";
import type { GeographyCity } from "@/lib/types";

const cardClassName =
  "relative overflow-hidden rounded-2xl border border-[var(--border)] bg-white p-6";

type CityDiscoveryCardProps = {
  city: GeographyCity;
};

function ComingSoonRibbon() {
  return (
    <div className="city-coming-soon-corner" aria-hidden="true">
      <span className="city-coming-soon-ribbon">COMING SOON</span>
    </div>
  );
}

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
      <ComingSoonRibbon />
      <h2 className="text-lg font-semibold">{city.name_en}</h2>
      {city.region ? (
        <p className="mt-2 text-sm text-[var(--muted)]">{city.region}</p>
      ) : null}
    </div>
  );
}

export { isActiveLaunchCity };
