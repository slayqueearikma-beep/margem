"use client";

import Link from "next/link";
import type { AppLocale } from "@/lib/i18n/video-messages";
import { videoMessages } from "@/lib/i18n/video-messages";

type DriverProVideoRibbonProps = {
  locale: AppLocale;
};

export function DriverProVideoRibbon({ locale }: DriverProVideoRibbonProps) {
  const t = videoMessages(locale);

  return (
    <div
      className="absolute right-0 top-0 z-10 flex min-w-[5.5rem] flex-col items-end rounded-bl-xl rounded-tr-2xl bg-[var(--primary)] px-2.5 py-1.5 text-right text-white shadow-sm"
      aria-label={t.driverProRibbonAria}
    >
      <span className="text-[10px] font-bold uppercase leading-tight tracking-wide">
        {t.driverProRibbonLabel}
      </span>
      <span className="text-[11px] font-semibold leading-tight">{t.driverProRibbonPrice}</span>
      <Link
        href="/seller/premium"
        className="mt-0.5 text-[10px] font-medium leading-tight underline underline-offset-2 hover:no-underline"
      >
        {t.upgradeAction}
      </Link>
    </div>
  );
}
