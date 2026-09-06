"use client";

import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { cityDisplayName } from "@/lib/city-name";
import { isActiveLaunchCity } from "@/lib/launch-cities";
import type { GeographyCity } from "@/lib/types";

const cardClassName =
  "relative overflow-hidden rounded-2xl border border-[var(--border)] bg-white p-6";

type CityDiscoveryCardProps = {
  city: GeographyCity;
};

function ComingSoonRibbon({ label }: { label: string }) {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute end-0 top-0 z-10 h-[76px] w-[76px] overflow-hidden rounded-se-2xl"
    >
      <span className="absolute end-[-26px] top-[14px] w-28 rotate-45 bg-[var(--cream)] px-0 py-1 text-center text-[9px] font-bold leading-none tracking-widest text-[var(--foreground)] shadow-sm">
        {label}
      </span>
    </div>
  );
}

export function CityDiscoveryCard({ city }: CityDiscoveryCardProps) {
  const locale = useLocale();
  const t = useTranslations("cities");
  const active = isActiveLaunchCity(city);
  const displayName = cityDisplayName(city, locale);

  if (active) {
    return (
      <Link
        href={`/cities/${city.slug}`}
        className={`${cardClassName} transition hover:border-[var(--primary)] hover:shadow-sm`}
      >
        <h2 className="text-lg font-semibold">{displayName}</h2>
        {city.region ? (
          <p className="mt-2 text-sm text-[var(--muted)]">{city.region}</p>
        ) : null}
      </Link>
    );
  }

  return (
    <div className={cardClassName} aria-label={t("comingSoonAria", { cityName: displayName })}>
      <ComingSoonRibbon label={t("comingSoonRibbon")} />
      <h2 className="text-lg font-semibold">{displayName}</h2>
      {city.region ? (
        <p className="mt-2 text-sm text-[var(--muted)]">{city.region}</p>
      ) : null}
    </div>
  );
}

export { isActiveLaunchCity };
