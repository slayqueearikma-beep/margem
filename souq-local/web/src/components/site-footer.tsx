import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { BRAND, getPublicApiBaseUrl } from "@/lib/config";

export async function SiteFooter() {
  const t = await getTranslations("footer");
  const apiBase = getPublicApiBaseUrl();

  return (
    <footer className="mt-16 border-t border-[var(--border)] bg-white">
      <div className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 md:grid-cols-3 lg:px-8">
        <div>
          <p className="text-lg font-semibold">{BRAND.name}</p>
          <p className="mt-2 text-sm text-[var(--muted)]">{t("tagline")}</p>
        </div>
        <div>
          <p className="text-sm font-semibold">{t("discover")}</p>
          <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
            <li>
              <Link href="/search" className="hover:text-[var(--primary)]">
                {t("searchMarketplace")}
              </Link>
            </li>
            <li>
              <Link href="/categories" className="hover:text-[var(--primary)]">
                {t("browseCategories")}
              </Link>
            </li>
            <li>
              <Link href="/sellers" className="hover:text-[var(--primary)]">
                {t("localBusinesses")}
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="text-sm font-semibold">{t("legal")}</p>
          <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
            <li>
              <a href={`${apiBase}/privacy`} className="hover:text-[var(--primary)]">
                {t("privacy")}
              </a>
            </li>
            <li>
              <a href={`${apiBase}/terms`} className="hover:text-[var(--primary)]">
                {t("terms")}
              </a>
            </li>
          </ul>
          <p className="mt-6 text-xs text-[var(--muted)]">{t("browseNote")}</p>
        </div>
      </div>
      <div className="border-t border-[var(--border)] px-4 py-4 text-center text-xs text-[var(--muted)]">
        {t("copyright", { year: new Date().getFullYear(), brand: BRAND.name })}
      </div>
    </footer>
  );
}
