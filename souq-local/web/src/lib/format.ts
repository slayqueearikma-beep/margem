import { intlLocale, toCategoryLocale } from "@/i18n/locale";
import type { Category } from "./types";

export function formatPrice(
  amount: number | null | undefined,
  negotiable?: boolean,
  locale = "ar",
): string {
  if (negotiable && amount == null) {
    return locale === "ar"
      ? "السعر عند الطلب"
      : locale === "fr"
        ? "Prix sur demande"
        : "Price on request";
  }
  if (amount == null) {
    return locale === "ar"
      ? "تواصل للسعر"
      : locale === "fr"
        ? "Contactez pour le prix"
        : "Contact for price";
  }
  return `${amount.toLocaleString(intlLocale(locale))} MAD`;
}

export function formatRating(value: number, locale = "ar"): string {
  if (value > 0) {
    return value.toLocaleString(intlLocale(locale), { maximumFractionDigits: 1 });
  }
  return locale === "ar" ? "جديد" : locale === "fr" ? "Nouveau" : "New";
}

export function categoryLabel(category: Category, locale = "ar"): string {
  const normalized = toCategoryLocale(locale);
  if (normalized === "fr") return category.name_fr || category.name_en;
  if (normalized === "ar") return category.name_ar || category.name_en;
  return category.name_en;
}

export function slugifyCity(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

export function cityFromSlug(slug: string, candidates: string[]): string | null {
  const normalized = slug.toLowerCase();
  return (
    candidates.find((city) => slugifyCity(city) === normalized) ||
    candidates.find((city) => city.toLowerCase() === normalized.replace(/-/g, " ")) ||
    null
  );
}

export function truncate(text: string, max = 160): string {
  const cleaned = text.trim();
  if (cleaned.length <= max) return cleaned;
  return `${cleaned.slice(0, max - 1)}…`;
}

export function verificationLabel(status: string, locale = "ar"): string | null {
  if (status === "verified") {
    return locale === "ar" ? "موثّق" : locale === "fr" ? "Vérifié" : "Verified";
  }
  if (status === "pending") {
    return locale === "ar"
      ? "التوثيق قيد المراجعة"
      : locale === "fr"
        ? "Vérification en cours"
        : "Verification pending";
  }
  return null;
}

export { safeExternalHref as externalHref } from "./security";
