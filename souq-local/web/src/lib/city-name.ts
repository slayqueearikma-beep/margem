import type { GeographyCity } from "./types";
import { toCategoryLocale } from "@/i18n/locale";

export function cityDisplayName(
  city: Pick<GeographyCity, "name_en" | "name_ar" | "name_fr">,
  locale: string,
): string {
  const normalized = toCategoryLocale(locale);
  if (normalized === "ar") return city.name_ar || city.name_en;
  if (normalized === "fr") return city.name_fr || city.name_en;
  return city.name_en;
}
