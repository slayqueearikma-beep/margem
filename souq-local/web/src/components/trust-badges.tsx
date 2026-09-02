"use client";

import { useTranslations } from "next-intl";

export function TrustBadges({ verified }: { verified?: boolean }) {
  const t = useTranslations("trust");
  if (!verified) return null;

  return (
    <div className="flex flex-wrap gap-1.5">
      <span className="rounded-full bg-green-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-green-700">
        {t("verified")}
      </span>
    </div>
  );
}
