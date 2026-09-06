import { getLocale, getTranslations } from "next-intl/server";
import { CityDiscoveryCard } from "@/components/city-discovery-card";
import { LAUNCH_CITIES } from "@/lib/config";
import { slugifyCity } from "@/lib/format";
import { fetchGeographyCities } from "@/lib/marketplace-api";
import { buildPageMetadata } from "@/lib/seo";
import type { GeographyCity } from "@/lib/types";

export async function generateMetadata() {
  const t = await getTranslations("meta");
  const locale = await getLocale();
  return buildPageMetadata({
    title: t("cities.title"),
    description: t("cities.description"),
    path: "/cities",
    locale,
  });
}

export default async function CitiesPage() {
  const t = await getTranslations("cities");
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
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="mt-2 text-[var(--muted)]">{t("description")}</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cities.map((city) => (
          <CityDiscoveryCard key={city.id} city={city} />
        ))}
      </div>
    </div>
  );
}
