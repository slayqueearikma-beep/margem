"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter, usePathname } from "@/i18n/navigation";
import { locales, type AppLocale } from "@/i18n/routing";

const localeLabels: Record<AppLocale, string> = {
  ar: "العربية",
  fr: "Français",
  en: "English",
};

export function LanguageSwitcher() {
  const locale = useLocale() as AppLocale;
  const router = useRouter();
  const pathname = usePathname();
  const t = useTranslations("language");

  function onChange(nextLocale: string) {
    if (!locales.includes(nextLocale as AppLocale)) return;
    router.replace(pathname, { locale: nextLocale as AppLocale });
  }

  return (
    <label className="flex items-center gap-2 text-sm">
      <span className="sr-only">{t("label")}</span>
      <select
        value={locale}
        onChange={(event) => onChange(event.target.value)}
        aria-label={t("label")}
        className="rounded-full border border-[var(--border)] bg-white px-3 py-2 text-sm font-medium text-[var(--foreground)] outline-none ring-[var(--primary)] focus:ring-2"
      >
        {locales.map((code) => (
          <option key={code} value={code}>
            {localeLabels[code]}
          </option>
        ))}
      </select>
    </label>
  );
}
