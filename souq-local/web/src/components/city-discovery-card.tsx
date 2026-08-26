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
    <div
      className="pointer-events-none absolute -right-px -top-px z-10 h-[4.75rem] w-[4.75rem] overflow-hidden rounded-tr-2xl sm:h-[5.25rem] sm:w-[5.25rem]"
      aria-hidden="true"
    >
      <span className="absolute right-[-1.625rem] top-[0.875rem] w-[7rem] rotate-45 bg-[var(--cream)] py-[0.3125rem] text-center text-[9px] font-bold leading-none tracking-[0.1em] text-[var(--foreground)] shadow-sm sm:right-[-1.5rem] sm:top-4 sm:w-[7.5rem] sm:text-[10px]">
        COMING SOON
      </span>
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
