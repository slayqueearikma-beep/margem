export type AppLocale = "en" | "fr" | "ar";

export function resolveLocale(value: string | null | undefined): AppLocale {
  if (value === "fr" || value === "ar") return value;
  return "en";
}
