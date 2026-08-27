"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BRAND } from "@/lib/config";
import { brandLogoUrl } from "@/lib/media";

const navLinks = [
  { href: "/", label: "Home" },
  { href: "/search", label: "Search" },
  { href: "/categories", label: "Categories" },
  { href: "/products", label: "Products" },
  { href: "/services", label: "Services" },
  { href: "/sellers", label: "Businesses" },
  { href: "/cities", label: "Cities" },
];

export function SiteHeader() {
  const pathname = usePathname();

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
          {navLinks.map((link) => {
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
                {link.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <Link
            href="/search"
            className="rounded-full bg-[var(--primary)] px-4 py-2 text-sm font-semibold text-white transition hover:bg-blue-700"
          >
            Explore
          </Link>
        </div>
      </div>

      <nav className="flex gap-1 overflow-x-auto border-t border-[var(--border)] px-4 py-2 md:hidden">
        {navLinks.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="whitespace-nowrap rounded-full bg-gray-100 px-3 py-1.5 text-xs font-medium text-[var(--foreground)]"
          >
            {link.label}
          </Link>
        ))}
      </nav>
    </header>
  );
}
