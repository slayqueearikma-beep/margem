import { defineRouting } from "next-intl/routing";

export const locales = ["ar", "fr", "en"] as const;
export type AppLocale = (typeof locales)[number];

export const routing = defineRouting({
  locales,
  defaultLocale: "ar",
  localePrefix: "never",
  localeCookie: {
    name: "DRIBEX_LOCALE",
    maxAge: 60 * 60 * 24 * 365,
  },
});
