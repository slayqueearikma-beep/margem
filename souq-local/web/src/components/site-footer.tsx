import Link from "next/link";
import { BRAND, getPublicApiBaseUrl } from "@/lib/config";

export function SiteFooter() {
  const apiBase = getPublicApiBaseUrl();
  return (
    <footer className="mt-16 border-t border-[var(--border)] bg-white">
      <div className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 md:grid-cols-3 lg:px-8">
        <div>
          <p className="text-lg font-semibold">{BRAND.name}</p>
          <p className="mt-2 text-sm text-[var(--muted)]">{BRAND.tagline}</p>
        </div>
        <div>
          <p className="text-sm font-semibold">Discover</p>
          <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
            <li>
              <Link href="/search" className="hover:text-[var(--primary)]">
                Search marketplace
              </Link>
            </li>
            <li>
              <Link href="/categories" className="hover:text-[var(--primary)]">
                Browse categories
              </Link>
            </li>
            <li>
              <Link href="/sellers" className="hover:text-[var(--primary)]">
                Local businesses
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="text-sm font-semibold">Legal</p>
          <ul className="mt-3 space-y-2 text-sm text-[var(--muted)]">
            <li>
              <a href={`${apiBase}/privacy`} className="hover:text-[var(--primary)]">
                Privacy
              </a>
            </li>
            <li>
              <a href={`${apiBase}/terms`} className="hover:text-[var(--primary)]">
                Terms
              </a>
            </li>
          </ul>
          <p className="mt-6 text-xs text-[var(--muted)]">
            Browse publicly without an account. Sign in on the mobile app for favorites,
            messaging, and seller tools.
          </p>
        </div>
      </div>
      <div className="border-t border-[var(--border)] px-4 py-4 text-center text-xs text-[var(--muted)]">
        © {new Date().getFullYear()} {BRAND.name}. All rights reserved.
      </div>
    </footer>
  );
}
