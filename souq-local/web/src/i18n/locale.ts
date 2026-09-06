import type { AppLocale } from "./routing";

export function isRtlLocale(locale: string): boolean {
  return locale === "ar";
}

export function localeDirection(locale: string): "rtl" | "ltr" {
  return isRtlLocale(locale) ? "rtl" : "ltr";
}

/** BCP-47 tags for Intl formatters (numbers, dates). */
export function intlLocale(locale: AppLocale | string): string {
  if (locale === "ar") return "ar-MA";
  if (locale === "fr") return "fr-MA";
  return "en-MA";
}

export function toCategoryLocale(locale: AppLocale | string): "ar" | "fr" | "en" {
  if (locale === "ar" || locale === "fr") return locale;
  return "en";
}
