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
      aria-hidden="true"
      style={{
        position: "absolute",
        top: 0,
        right: 0,
        width: 76,
        height: 76,
        overflow: "hidden",
        borderTopRightRadius: 16,
        pointerEvents: "none",
        zIndex: 10,
      }}
    >
      <span
        style={{
          position: "absolute",
          top: 14,
          right: -26,
          width: 112,
          transform: "rotate(45deg)",
          background: "var(--cream)",
          color: "var(--foreground)",
          padding: "4px 0",
          textAlign: "center",
          fontSize: 9,
          fontWeight: 700,
          letterSpacing: "0.1em",
          lineHeight: 1,
          boxShadow: "0 1px 2px rgb(17 24 39 / 8%)",
          whiteSpace: "nowrap",
        }}
      >
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
