"use client";

import { useTranslations } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";
import { BRAND } from "@/lib/config";
import { brandLogoUrl } from "@/lib/media";
import { LanguageSwitcher } from "@/components/language-switcher";

const navHrefs = [
  { href: "/", key: "home" },
  { href: "/search", key: "search" },
  { href: "/categories", key: "categories" },
  { href: "/products", key: "products" },
  { href: "/services", key: "services" },
  { href: "/sellers", key: "businesses" },
  { href: "/cities", key: "cities" },
] as const;

export function SiteHeader() {
  const pathname = usePathname();
  const t = useTranslations("nav");

  return (
    <header className="sticky top-0 z-40 border-b border-[var(--border)] bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-7xl items-center gap-4 px-4 py-3 sm:px-6 lg:px-8">
        <Link href="/" className="flex shrink-0 items-center gap-3">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={brandLogoUrl()}
            alt={BRAND.name}
            className="h-10 w-auto object-contain"
            onError={(event) => {
              event.currentTarget.style.display = "none";
            }}
          />
          <span className="text-lg font-semibold tracking-tight text-[var(--foreground)]">
            {BRAND.name}
          </span>
        </Link>

        <nav className="hidden flex-1 items-center justify-center gap-1 md:flex">
          {navHrefs.map((link) => {
            const active =
              link.href === "/"
                ? pathname === "/"
                : pathname.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-full px-3 py-2 text-sm font-medium transition ${
                  active
                    ? "bg-[var(--primary-muted)] text-[var(--primary)]"
                    : "text-[var(--muted)] hover:bg-gray-100 hover:text-[var(--foreground)]"
                }`}
              >
                {t(link.key)}
              </Link>
            );
          })}
        </nav>

        <div className="ms-auto flex items-center gap-2">
          <LanguageSwitcher />
          <Link
            href="/search"
            className="rounded-full bg-[var(--primary)] px-4 py-2 text-sm font-semibold text-white transition hover:bg-blue-700"
          >
            {t("explore")}
          </Link>
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-t border-[var(--border)] px-4 py-2 md:hidden">
        {navHrefs.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="whitespace-nowrap rounded-full bg-gray-100 px-3 py-1.5 text-xs font-medium text-[var(--foreground)]"
          >
            {t(link.key)}
          </Link>
        ))}
      </nav>
    </header>
  );
}
