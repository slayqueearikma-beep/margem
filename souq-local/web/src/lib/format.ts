import type { Category } from "./types";

export function formatPrice(
  amount: number | null | undefined,
  negotiable?: boolean,
): string {
  if (negotiable && amount == null) {
    return "Price on request";
  }
  if (amount == null) {
    return "Contact for price";
  }
  return `${amount.toLocaleString("fr-MA")} MAD`;
}

export function formatRating(value: number): string {
  return value > 0 ? value.toFixed(1) : "New";
}

export function categoryLabel(category: Category, locale = "en"): string {
  if (locale === "fr") return category.name_fr || category.name_en;
  if (locale === "ar") return category.name_ar || category.name_en;
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

export function verificationLabel(status: string): string | null {
  if (status === "verified") return "Verified";
  if (status === "pending") return "Verification pending";
  return null;
}

export { safeExternalHref as externalHref } from "./security";
