"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef } from "react";
import { apiFetch } from "@/lib/api";
import { getPublicApiBaseUrl } from "@/lib/config";
import { resolveAdAssetUrl } from "@/lib/media";
import { safeExternalHref } from "@/lib/security";
import type { PlatformAdvertisement } from "@/lib/types";

type AdvertisementBannerProps = {
  ad: PlatformAdvertisement;
  placement: string;
  className?: string;
  targeting?: {
    marketplaceSlug?: string;
    city?: string;
    categorySlug?: string;
    listingType?: string;
  };
};

function viewerStorageKey(): string {
  if (typeof window === "undefined") return "anonymous";
  const existing = window.localStorage.getItem("dribex-ad-viewer");
  if (existing) return existing;
  const created =
    typeof crypto !== "undefined" && "randomUUID" in crypto
      ? crypto.randomUUID()
      : `viewer-${Date.now()}`;
  window.localStorage.setItem("dribex-ad-viewer", created);
  return created;
}

export function AdvertisementBanner({
  ad,
  placement,
  className = "",
  targeting = {},
}: AdvertisementBannerProps) {
  const imageUrl = resolveAdAssetUrl(ad, "image");
  const videoUrl = ad.video_url ? resolveAdAssetUrl(ad, "video") : null;
  const clickHref = ad.click_url || safeExternalHref(ad.target_url);
  const recordedRef = useRef(false);
  const viewKey = useMemo(
    () =>
      typeof crypto !== "undefined" && "randomUUID" in crypto
        ? crypto.randomUUID()
        : `view-${ad.id}-${Date.now()}`,
    [ad.id],
  );

  useEffect(() => {
    if (recordedRef.current) return;
    recordedRef.current = true;
    const viewer = viewerStorageKey();
    void apiFetch(
      "/ads/impressions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Ad-Viewer": viewer,
        },
        body: JSON.stringify({
          campaign_id: ad.id,
          placement,
          view_key: viewKey,
          marketplace_slug: targeting.marketplaceSlug,
          city: targeting.city,
          category_slug: targeting.categorySlug,
          listing_type: targeting.listingType,
        }),
      },
      "client",
    ).catch(() => {
      // Ads must never break the page.
    });
  }, [ad.id, placement, viewKey, targeting]);

  if (!imageUrl || !clickHref) return null;

  const resolvedClick =
    clickHref.startsWith("http") || clickHref.startsWith("/")
      ? clickHref.startsWith("/")
        ? `${getPublicApiBaseUrl()}${clickHref}`
        : clickHref
      : null;
  if (!resolvedClick) return null;

  return (
    <aside
      className={`rounded-2xl border border-dashed border-[var(--border)] bg-[var(--surface)] p-4 ${className}`}
      aria-label="Advertisement"
    >
      <p className="mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted)]">
        Advertisement
      </p>
      <Link
        href={resolvedClick}
        target="_blank"
        rel="noopener noreferrer sponsored"
        className="group block overflow-hidden rounded-xl border border-[var(--border)] bg-white transition hover:border-[var(--primary)] hover:shadow-sm"
      >
        <div className="aspect-[21/9] w-full overflow-hidden bg-[var(--cream)]">
          {videoUrl ? (
            <video
              src={videoUrl}
              className="h-full w-full object-cover"
              muted
              playsInline
              autoPlay
              loop
            />
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={imageUrl}
              alt={ad.title}
              className="h-full w-full object-cover transition group-hover:scale-[1.01]"
              loading="lazy"
            />
          )}
        </div>
        <div className="px-4 py-3">
          <p className="font-semibold text-[var(--foreground)]">{ad.title}</p>
          {ad.description ? (
            <p className="mt-1 text-sm text-[var(--muted)]">{ad.description}</p>
          ) : null}
        </div>
      </Link>
    </aside>
  );
}
