import Link from "next/link";
import { safeExternalHref, sanitizeMediaSource } from "@/lib/security";
import type { PlatformAdvertisement } from "@/lib/types";

type AdvertisementBannerProps = {
  ad: PlatformAdvertisement;
  className?: string;
};

export function AdvertisementBanner({ ad, className = "" }: AdvertisementBannerProps) {
  const imageUrl = sanitizeMediaSource(ad.image_url);
  const targetUrl = safeExternalHref(ad.target_url);
  if (!imageUrl || !targetUrl) return null;

  return (
    <aside
      className={`rounded-2xl border border-dashed border-[var(--border)] bg-[var(--surface)] p-4 ${className}`}
      aria-label="Advertisement"
    >
      <p className="mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
        Advertisement
      </p>
      <Link
        href={targetUrl}
        target="_blank"
        rel="noopener noreferrer sponsored"
        className="group block overflow-hidden rounded-xl border border-[var(--border)] bg-white transition hover:border-[var(--primary)] hover:shadow-sm"
      >
        <div className="aspect-[21/9] w-full overflow-hidden bg-[var(--cream)]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={imageUrl}
            alt={ad.title}
            className="h-full w-full object-cover transition group-hover:scale-[1.01]"
            loading="lazy"
          />
        </div>
        <div className="px-4 py-3">
          <p className="font-semibold text-[var(--foreground)]">{ad.title}</p>
        </div>
      </Link>
    </aside>
  );
}
