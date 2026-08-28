"use client";

import Link from "next/link";
import type { AppLocale } from "@/lib/i18n/video-messages";
import { videoMessages } from "@/lib/i18n/video-messages";

type DriverProVideoBannerProps = {
  locale: AppLocale;
};

export function DriverProVideoBanner({ locale }: DriverProVideoBannerProps) {
  const t = videoMessages(locale);

  return (
    <section className="rounded-2xl border border-[var(--border)] bg-[var(--primary-muted)] p-5">
      <p className="text-xs font-semibold uppercase tracking-wide text-[var(--primary)]">
        {t.videoListingsTitle}
      </p>
      <p className="mt-2 text-sm text-[var(--foreground)]">{t.videoListingsBody}</p>
      <p className="mt-2 text-sm font-medium text-[var(--foreground)]">{t.driverProPrice}</p>
      <Link
        href="/seller/premium"
        className="mt-4 inline-flex rounded-xl bg-[var(--primary)] px-4 py-2 text-sm font-semibold text-white"
      >
        {t.upgradeToDriverPro}
      </Link>
    </section>
  );
}
